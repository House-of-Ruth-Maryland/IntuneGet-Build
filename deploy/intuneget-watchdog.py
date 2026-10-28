#!/usr/bin/python3 -I
"""Watchdog for HRM's IntuneGet VM. Run by intuneget-watchdog.timer every 5 minutes.

Checks the app's health, the server status file written by intuneget-status
(disk, last deploy, update-check and notification timers, the tunnel) and posts
to the IT Ops Teams channel only when something changes: once when a problem is
confirmed (seen on two checks in a row), once a day while it lasts, and once
when it clears. It stays quiet while a deploy is running.

Posts go to the first flow URL in WEBHOOK_MANAGED_IDENTITY_URLS (the app's
.env.local), signed with the VM's managed identity like the app's own Teams
posts. Nothing secret or client-related is sent.

    intuneget-watchdog          check and alert (the timer)
    intuneget-watchdog status   print current problems without posting
    intuneget-watchdog test     post a test message to Teams
"""

import fcntl
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

ENV_FILE = os.environ.get('ENV_FILE', '/opt/intuneget/.env.local')
DATA_DIR = os.environ.get('DATA_DIR', '/var/lib/docker/volumes/intuneget_intuneget-data/_data')
STATUS_FILE = os.environ.get('STATUS_FILE', os.path.join(DATA_DIR, 'hrm-status.json'))
STATE_FILE = os.environ.get('WATCHDOG_STATE', '/var/lib/intuneget-watchdog/state.json')
DEPLOY_LOCK = os.environ.get('LOCK_FILE', '/run/intuneget-deploy.lock')
HEALTH_URL = os.environ.get('HEALTH_URL', 'http://127.0.0.1:3000/api/health')
IMDS_URL = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fservice.flow.microsoft.com%2F'

STATUS_STALE_MIN = 15
DISK_WARNING = 0.85
TIMER_LATE_HOURS = 13  # the update check and alerts run every 12 hours
CONFIRM_RUNS = 2
REMIND_HOURS = 24

LABELS = {
    'app': 'The IntuneGet app is not responding as healthy',
    'status': 'The server status file has stopped updating',
    'disk': 'Disk space is running low',
    'deploy': 'The last deploy did not finish',
    'updateCheck': 'The scheduled update check failed or is late',
    'notifications': 'The scheduled update alerts failed or are late',
    'tunnel': 'The Cloudflare tunnel is not running',
    'tunnelUpdate': 'The nightly cloudflared update failed',
}


def now():
    return datetime.now(timezone.utc)


def parse_time(value):
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    except (AttributeError, ValueError):
        return None


def env_value(name):
    try:
        with open(ENV_FILE) as handle:
            for line in handle:
                key, _, value = line.strip().partition('=')
                if key == name:
                    return value.strip().strip('"\'')
    except OSError:
        pass
    return ''


def deploy_running():
    try:
        with open(DEPLOY_LOCK, 'a') as handle:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(handle, fcntl.LOCK_UN)
            return False
    except BlockingIOError:
        return True
    except OSError:
        return False


def app_healthy():
    try:
        with urllib.request.urlopen(HEALTH_URL, timeout=10) as response:
            return json.load(response).get('status') == 'healthy'
    except Exception:
        return False


def late_or_failed(run, at_now):
    if not run or not run.get('at'):
        return False  # never ran yet; nothing to compare
    at = parse_time(run['at'])
    late = at is not None and (at_now - at).total_seconds() > TIMER_LATE_HOURS * 3600
    return run.get('result') not in (None, 'success') or late


def find_problems(at_now):
    """Returns {key: detail} for every current problem."""
    problems = {}
    if not app_healthy():
        problems['app'] = 'The health check did not answer "healthy".'
    try:
        with open(STATUS_FILE) as handle:
            status = json.load(handle)
    except (OSError, ValueError):
        problems['status'] = 'The status file is missing or unreadable.'
        return problems
    generated = parse_time(status.get('generatedAt'))
    if generated is None or (at_now - generated).total_seconds() > STATUS_STALE_MIN * 60:
        problems['status'] = f"Last written {status.get('generatedAt', 'never')}."
        return problems
    disk = status.get('disk') or {}
    if disk.get('totalKb') and disk['usedKb'] / disk['totalKb'] >= DISK_WARNING:
        problems['disk'] = f"{round(100 * disk['usedKb'] / disk['totalKb'])}% used."
    deploy = status.get('lastDeploy')
    if deploy and deploy.get('result') not in ('deployed', 'waiting'):
        problems['deploy'] = f"{deploy.get('result', '').replace('_', ' ')}: {deploy.get('from')} to {deploy.get('to')}."
    if late_or_failed(status.get('updateCheck'), at_now):
        problems['updateCheck'] = f"Last run {status['updateCheck'].get('at')}, result {status['updateCheck'].get('result')}."
    if late_or_failed(status.get('notifications'), at_now):
        problems['notifications'] = f"Last run {status['notifications'].get('at')}, result {status['notifications'].get('result')}."
    tunnel = status.get('tunnel') or {}
    if not tunnel.get('running'):
        problems['tunnel'] = 'cloudflared is not active on the VM.'
    elif (tunnel.get('lastUpdate') or {}).get('result') not in (None, 'success'):
        problems['tunnelUpdate'] = f"Result {tunnel['lastUpdate'].get('result')}."
    return problems


def card(title, color, facts, app_url):
    return {
        'type': 'message',
        'attachments': [{
            'contentType': 'application/vnd.microsoft.card.adaptive',
            'content': {
                '$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
                'type': 'AdaptiveCard',
                'version': '1.4',
                'body': [
                    {'type': 'TextBlock', 'text': title, 'size': 'Large', 'weight': 'Bolder', 'color': color, 'wrap': True},
                    {'type': 'FactSet', 'facts': [{'title': key, 'value': value} for key, value in facts]},
                ],
                'actions': [{'type': 'Action.OpenUrl', 'title': 'Open IntuneGet', 'url': app_url}] if app_url else [],
            },
        }],
    }


def post(payload):
    url = env_value('WEBHOOK_MANAGED_IDENTITY_URLS').replace(',', ' ').split()
    if not url:
        raise RuntimeError('WEBHOOK_MANAGED_IDENTITY_URLS is not set in ' + ENV_FILE)
    request = urllib.request.Request(IMDS_URL, headers={'Metadata': 'true'})
    with urllib.request.urlopen(request, timeout=10) as response:
        token = json.load(response)['access_token']
    request = urllib.request.Request(
        url[0], data=json.dumps(payload).encode(), method='POST',
        headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}'})
    # Never follow redirects with the token (same rule as the app's patch 0007).
    opener = urllib.request.build_opener(type('NoRedirect', (urllib.request.HTTPRedirectHandler,), {'redirect_request': lambda *a: None})())
    with opener.open(request, timeout=15) as response:
        if response.status >= 300:
            raise RuntimeError(f'Teams flow answered {response.status}')


def load_state():
    try:
        with open(STATE_FILE) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + '.tmp'
    with open(tmp, 'w') as handle:
        json.dump(state, handle, indent=2)
    os.replace(tmp, STATE_FILE)


def server_facts(extra):
    try:
        with open(STATUS_FILE) as handle:
            version = json.load(handle).get('version') or 'unknown'
    except (OSError, ValueError):
        version = 'unknown'
    return extra + [('Server', f'IntuneGet VM, {version}')]


def run(at_now):
    if deploy_running():
        print('intuneget-watchdog: deploy in progress; skipped')
        return
    app_url = env_value('NEXT_PUBLIC_APP_URL')
    state = load_state()
    problems = find_problems(at_now)
    stamp = at_now.strftime('%Y-%m-%dT%H:%M:%SZ')

    for key, detail in problems.items():
        entry = state.setdefault(key, {'firstSeen': stamp, 'count': 0, 'alertedAt': None})
        entry['count'] += 1
        entry['detail'] = detail
        alerted = parse_time(entry['alertedAt']) if entry['alertedAt'] else None
        due = entry['count'] >= CONFIRM_RUNS and (alerted is None or (at_now - alerted).total_seconds() >= REMIND_HOURS * 3600)
        if due:
            title = ('Still a problem: ' if alerted else '') + LABELS[key]
            post(card(title, 'Attention', server_facts([('Detail', detail), ('Since', entry['firstSeen'])]), app_url))
            entry['alertedAt'] = stamp
            print(f'intuneget-watchdog: alerted {key}')

    for key in [k for k in state if k not in problems]:
        entry = state.pop(key)
        if entry.get('alertedAt'):
            post(card(f'Resolved: {LABELS.get(key, key)}', 'Good', server_facts([('Since', entry['firstSeen']), ('Cleared', stamp)]), app_url))
            print(f'intuneget-watchdog: resolved {key}')

    save_state(state)
    print(f"intuneget-watchdog: {len(problems)} problem(s){': ' + ', '.join(problems) if problems else ''}")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else 'run'
    at_now = now()
    if command == 'run':
        run(at_now)
    elif command == 'status':
        print(json.dumps(find_problems(at_now), indent=2))
    elif command == 'test':
        post(card('Test: IntuneGet watchdog is connected', 'Good', server_facts([('Sent', at_now.strftime('%Y-%m-%d %H:%M UTC'))]), env_value('NEXT_PUBLIC_APP_URL')))
        print('intuneget-watchdog: test message sent')
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
