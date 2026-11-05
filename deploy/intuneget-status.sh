#!/usr/bin/env bash
# Server status for HRM's IntuneGet Home page. Run by intuneget-status.timer.
#
# Writes hrm-status.json into the app's data volume: the running version, the
# last deploy and backup, disk space, the update-check and notification timers,
# cloudflared, and whether the server's Intune reads work (patch 0032). The app reads it through /api/hrm/status; it never gets
# access to the host. Nothing secret goes in the file.
set -euo pipefail

DEFAULTS_FILE=${DEFAULTS_FILE:-/etc/default/intuneget-deploy}
if [ -r "$DEFAULTS_FILE" ]; then set -a; . "$DEFAULTS_FILE"; set +a; fi

COMPOSE_DIR=${COMPOSE_DIR:-/opt/intuneget}
DATA_DIR=${DATA_DIR:-/var/lib/docker/volumes/intuneget_intuneget-data/_data}
BACKUP_DIR=${BACKUP_DIR:-$COMPOSE_DIR/backups}
STATE_DIR=${STATE_DIR:-/var/lib/intuneget-deploy}
SERVICE=${SERVICE:-web}
OUT=${STATUS_FILE:-$DATA_DIR/hrm-status.json}

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
  START_ENABLED="$(systemctl is-enabled intuneget-start-updates.timer 2>/dev/null || true)"

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
    detail = ', '.join(f"{c.get('name')} ({str(c.get('error') or 'failed')[:120]})" for c in failed[:5])
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
               'scheduledUpdates': scheduled_updates()},
    'offsiteBackup': (lambda raw: {k: v for k, v in json.loads(raw).items() if k in ('result', 'at', 'compressedBytes')} if raw.strip() else None)(os.environ['OFFSITE_JSON']),
    'tunnel': {'version': os.environ['CF_VERSION'] or None, 'running': os.environ['CF_ACTIVE'] == 'active',
               'lastUpdate': run(os.environ['CF_UPDATE_RUN'])},
}, indent=2))
PY
chmod 0644 "$tmp"
mv -f "$tmp" "$OUT"
