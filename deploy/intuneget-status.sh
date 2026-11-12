#!/usr/bin/env bash
# Server status for HRM's IntuneGet Home page. Run by intuneget-status.timer.
#
# Writes hrm-status.json into the app's data volume: the running version, the
# last deploy and backup, disk space, the update-check and notification timers,
# cloudflared, whether the server's Intune reads work (patch 0032), whether sign-in is
# limited to the IT admins group (patch 0056) and whether App updates is corrected after each deploy
# (patch 0057). The app reads it through /api/hrm/status; it never gets access to the host. Nothing
# secret goes in the file.
set -euo pipefail

DEFAULTS_FILE=${DEFAULTS_FILE:-/etc/default/intuneget-deploy}
if [ -r "$DEFAULTS_FILE" ]; then set -a; . "$DEFAULTS_FILE"; set +a; fi

COMPOSE_DIR=${COMPOSE_DIR:-/opt/intuneget}
DATA_DIR=${DATA_DIR:-/var/lib/docker/volumes/intuneget_intuneget-data/_data}
BACKUP_DIR=${BACKUP_DIR:-$COMPOSE_DIR/backups}
STATE_DIR=${STATE_DIR:-/var/lib/intuneget-deploy}
SERVICE=${SERVICE:-web}
OUT=${STATUS_FILE:-$DATA_DIR/hrm-status.json}
APP_URL=${APP_URL:-http://127.0.0.1:3000}
CRON_HEADER=${CRON_HEADER:-/etc/intuneget/cron-auth.header}

# Last run of a systemd unit: "<result> <exit time>", or empty if it never ran.
unit_run() {
  systemctl show --timestamp=utc "$1" -p Result -p ExecMainExitTimestamp --value 2>/dev/null | paste -sd'|' || true
}

# Last JSON results a cron unit printed (curl writes the app's reply to the journal).
unit_json() {
  journalctl -u "$1" -o cat --since "-${3:-3d}" --no-pager 2>/dev/null | grep '^{' | tail -n "${2:-1}" || true
}

container=$(docker ps -q --filter "label=com.docker.compose.service=$SERVICE" | head -n 1 || true)
image=$([ -n "$container" ] && docker inspect -f '{{.Config.Image}}' "$container" 2>/dev/null || true)
started=$([ -n "$container" ] && docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null || true)
# Patch 0056: whether the running app limits sign-in to the IT admins group. Like the app, it
# counts only when at least one entry is a well-formed group ID. Never records the value.
guid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
access_limited=$([ -n "$container" ] && docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$container" 2>/dev/null | grep -cE "^HRM_ADMIN_GROUP_IDS=(.*,)?[[:space:]]*${guid}[[:space:]]*(,|\$)" || true)
# Patch 0057: the app's "Version sync after deploy" verdict, read with the cron secret (sent from the
# root-only header file, never on the command line). Empty when the app or the header isn't there.
version_sync=$([ -r "$CRON_HEADER" ] && curl -fsS --max-time 10 -H @"$CRON_HEADER" "$APP_URL/api/cron/version-sync-status" 2>/dev/null || true)
backup=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)
backup_kb=$([ -n "$backup" ] && du -sk "$backup" | cut -f1 || true)

export IMAGE="$image" STARTED="$started" BACKUP="${backup##*/}" BACKUP_KB="$backup_kb" \
  DEPLOY_JSON="$(cat "$STATE_DIR/status.json" 2>/dev/null || true)" \
  DISK="$(df -Pk "$(dirname "$OUT")" | awk 'NR==2 {print $2" "$3}')" \
  CHECK_RUN="$(unit_run intuneget-cron@check-updates.service)" \
  NOTIFY_RUN="$(unit_run intuneget-cron@send-notifications.service)" \
  CF_VERSION="$(cloudflared --version 2>/dev/null | awk '{print $3}' || true)" \
  CF_ACTIVE="$(systemctl is-active cloudflared 2>/dev/null || true)" \
  CF_UPDATE_RUN="$(unit_run cloudflared-update.service)" \
  OFFSITE_JSON="$(cat /var/lib/intuneget-backup/last.json 2>/dev/null || true)" \
  CHECK_JSON="$(unit_json intuneget-cron@check-updates.service 2)" \
  SELFTEST_JSON="$(unit_json intuneget-cron@intune-self-test.service 1)" \
  SELFTEST_RUN="$(unit_run intuneget-cron@intune-self-test.service)" \
  SELFTEST_ENABLED="$(systemctl is-enabled intuneget-intune-self-test.timer 2>/dev/null || true)" \
  START_RUN="$(unit_run intuneget-cron@start-scheduled-updates.service)" \
  START_ENABLED="$(systemctl is-enabled intuneget-start-updates.timer 2>/dev/null || true)" \
  ACCESS_LIMITED="${access_limited:-}" \
  VERSION_SYNC_JSON="${version_sync:-}" \
  PREVIOUS_JSON="$(head -c 32768 "$OUT" 2>/dev/null || true)"

tmp=$(mktemp "$(dirname "$OUT")/.hrm-status.XXXXXX")
python3 -I - > "$tmp" <<'PY'
import json, os, re
from datetime import datetime, timezone

def run(value):
    # "success|Tue 2026-10-27 03:59:30 UTC" -> {"result", "at"}
    result, _, at = (value or '').partition('|')
    parsed = None
    m = re.search(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', at)
    if m:
        parsed = m.group(1).replace(' ', 'T') + 'Z'
    return {'result': result or None, 'at': parsed}

def backup_time(name):
    m = re.match(r'(\d{8}T\d{6}Z)', name or '')
    return datetime.strptime(m.group(1), '%Y%m%dT%H%M%SZ').strftime('%Y-%m-%dT%H:%M:%SZ') if m else None

def json_lines(raw):
    out = []
    for line in (raw or '').splitlines():
        try:
            value = json.loads(line)
        except ValueError:
            continue
        if isinstance(value, dict):
            out.append(value)
    return out

def hours_since(at):
    if not at:
        return None
    return (datetime.now(timezone.utc) - datetime.fromisoformat(at.replace('Z', '+00:00'))).total_seconds() / 3600

def read_failures(result):
    # Patch 0031 reports why install results or app activity couldn't be read (status codes only).
    parts = []
    for key, label in (('installStatus', 'Install results'), ('appInsights', 'App activity')):
        part = result.get(key) or {}
        if part.get('errors'):
            parts.append(f"{label}: {part.get('checked', 0)} read, {part['errors']} not read ({str(part.get('lastError') or 'no reason')[:120]})")
    return parts

def intune_reads(check_run):
    results = json_lines(os.environ['CHECK_JSON'])
    if not results:
        return None
    latest = read_failures(results[-1])
    # Two checks in a row, so one Intune outage doesn't raise an alert.
    failing = len(results) >= 2 and all(read_failures(r) for r in results[-2:])
    return {'ok': not failing, 'at': check_run['at'], 'detail': '; '.join(latest) or None}

def self_test():
    if os.environ['SELFTEST_ENABLED'] != 'enabled':
        return None
    unit = run(os.environ['SELFTEST_RUN'])
    if not unit['at']:
        return {'ok': True, 'at': None, 'detail': 'Not run yet.'}
    age = hours_since(unit['at'])
    if unit['result'] != 'success':
        return {'ok': False, 'at': unit['at'], 'detail': f"The self-test did not run ({unit['result']})."}
    if age is not None and age > 26:
        return {'ok': False, 'at': unit['at'], 'detail': 'The daily self-test is late.'}
    results = json_lines(os.environ['SELFTEST_JSON'])
    failed = [c for c in (results[-1].get('checks') or []) if not c.get('ok')] if results else []
    # Patch 0058: names only, never Graph's error text (that stays in the self-test's journal).
    detail = ' '.join(f"Couldn't read {str(c.get('name') or 'Intune')[:60]}." for c in failed[:5])
    return {'ok': not failed, 'at': unit['at'], 'detail': detail or None}

def scheduled_updates():
    if os.environ['START_ENABLED'] != 'enabled':
        return None
    unit = run(os.environ['START_RUN'])
    age = hours_since(unit['at'])
    if unit['at'] and unit['result'] != 'success':
        return {'ok': False, 'at': unit['at'], 'detail': f"Last run failed ({unit['result']})."}
    if age is not None and age > 2:
        return {'ok': False, 'at': unit['at'], 'detail': 'The hourly run is late.'}
    return {'ok': True, 'at': unit['at'], 'detail': None}

def app_access():
    # Patch 0056: the app shows its own view on Home; this copy is for anything reading the file.
    if os.environ['ACCESS_LIMITED'] == '':
        return None
    limited = os.environ['ACCESS_LIMITED'] != '0'
    return {'ok': limited, 'at': None, 'detail': None if limited else 'Not limited to a group.'}

def previous_check(key):
    try:
        value = (json.loads(os.environ['PREVIOUS_JSON']).get('checks') or {}).get(key)
    except (ValueError, AttributeError):
        return None
    return value if isinstance(value, dict) else None

def version_sync():
    # Patch 0057: the app works out the verdict; only its known fields are copied, with bounded text.
    # If the app didn't answer this time, keep the last verdict so a restart doesn't clear an alert.
    try:
        value = json.loads(os.environ['VERSION_SYNC_JSON']).get('versionSync')
    except (ValueError, AttributeError):
        value = None
    if not isinstance(value, dict) or not isinstance(value.get('ok'), bool):
        # A working verdict is kept for up to 30 minutes (a restart or deploy). A Failing one is kept
        # for up to 24 hours, the app's own window, so an app that stops answering never reads as
        # cleared to the watchdog. After that the row goes away.
        previous = previous_check('versionSync')
        try:
            age = hours_since(previous.get('readAt')) if previous and isinstance(previous.get('readAt'), str) else None
        except ValueError:
            age = None
        keep = 24 if previous and previous.get('ok') is False else 0.5
        return previous if age is not None and 0 <= age <= keep else None
    at = value.get('at') if isinstance(value.get('at'), str) and re.fullmatch(r'[0-9T:.\-]+Z', value.get('at')) else None
    detail = value.get('detail') if isinstance(value.get('detail'), str) and not value['ok'] else None
    return {'ok': value['ok'], 'at': at, 'detail': detail[:200] if detail else None,
            'readAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}

try:
    deploy = json.loads(os.environ['DEPLOY_JSON'])
except ValueError:
    deploy = None
total_kb, used_kb = (int(x) for x in os.environ['DISK'].split()) if os.environ['DISK'] else (0, 0)
image = os.environ['IMAGE']
print(json.dumps({
    'generatedAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'version': image.rsplit(':', 1)[-1] if ':' in image else None,
    'startedAt': os.environ['STARTED'] or None,
    'lastDeploy': {k: deploy.get(k) for k in ('time', 'result', 'from', 'to')} if deploy else None,
    'lastBackup': {'at': backup_time(os.environ['BACKUP']), 'sizeKb': int(os.environ['BACKUP_KB'] or 0)} if os.environ['BACKUP'] else None,
    'disk': {'totalKb': total_kb, 'usedKb': used_kb},
    'updateCheck': run(os.environ['CHECK_RUN']),
    'notifications': run(os.environ['NOTIFY_RUN']),
    'checks': {'intuneReads': intune_reads(run(os.environ['CHECK_RUN'])), 'intuneSelfTest': self_test(),
               'scheduledUpdates': scheduled_updates(), 'appAccess': app_access(),
               'versionSync': version_sync()},
    'offsiteBackup': (lambda raw: {k: v for k, v in json.loads(raw).items() if k in ('result', 'at', 'compressedBytes')} if raw.strip() else None)(os.environ['OFFSITE_JSON']),
    'tunnel': {'version': os.environ['CF_VERSION'] or None, 'running': os.environ['CF_ACTIVE'] == 'active',
               'lastUpdate': run(os.environ['CF_UPDATE_RUN'])},
}, indent=2))
PY
chmod 0644 "$tmp"
mv -f "$tmp" "$OUT"
