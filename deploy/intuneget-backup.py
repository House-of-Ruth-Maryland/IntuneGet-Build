#!/usr/bin/python3 -I
"""Nightly off-site backup of HRM's IntuneGet database. Run by intuneget-backup.timer.

Takes a consistent copy of the SQLite database while the app runs (SQLite's
online backup), compresses it, checks it opens, and uploads it to the Azure
Storage container in BACKUP_CONTAINER_URL as <prefix>/YYYY/MM/DD/intuneget-<time>.db.gz,
signed in as the VM's managed identity (no keys). The storage account's
lifecycle rule deletes copies after 31 days. Secrets (.env.local) are never
backed up here; they live on the VM and in the host's records.

The result goes to /var/lib/intuneget-backup/last.json, which the status
script and the watchdog read.

    intuneget-backup          back up now (the timer)
    intuneget-backup status   print the last result
"""

import gzip
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone

DEFAULTS_FILE = os.environ.get('DEFAULTS_FILE', '/etc/default/intuneget-deploy')
DATA_DIR = os.environ.get('DATA_DIR', '/var/lib/docker/volumes/intuneget_intuneget-data/_data')
DB_FILE = os.environ.get('DB_FILE', 'intuneget.db')
STATE_FILE = os.environ.get('BACKUP_STATE', '/var/lib/intuneget-backup/last.json')
IMDS = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F'


def setting(name):
    """From the environment, or the deploy defaults file (systemd loads it; by hand it may not be)."""
    if os.environ.get(name):
        return os.environ[name]
    try:
        with open(DEFAULTS_FILE) as handle:
            for line in handle:
                key, _, value = line.strip().partition('=')
                if key == name:
                    return value.strip().strip('"\'')
    except OSError:
        pass
    return ''


def now():
    return datetime.now(timezone.utc)


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + '.tmp'
    with open(tmp, 'w') as handle:
        json.dump(state, handle, indent=2)
    os.replace(tmp, STATE_FILE)


def snapshot(workdir):
    """Consistent copy of the live database, checked, then compressed."""
    source = os.path.join(DATA_DIR, DB_FILE)
    copy = os.path.join(workdir, 'intuneget.db')
    live = sqlite3.connect(f'file:{source}?mode=ro', uri=True)
    target = sqlite3.connect(copy)
    with target:
        live.backup(target)
    live.close()
    result = target.execute('PRAGMA integrity_check').fetchone()[0]
    target.close()
    if result != 'ok':
        raise RuntimeError(f'integrity check failed: {result}')
    packed = copy + '.gz'
    with open(copy, 'rb') as raw, gzip.open(packed, 'wb', compresslevel=9) as out:
        shutil.copyfileobj(raw, out)
    digest = hashlib.sha256()
    with open(packed, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return packed, os.path.getsize(copy), os.path.getsize(packed), digest.hexdigest()


def upload(path, blob_url):
    request = urllib.request.Request(IMDS, headers={'Metadata': 'true'})
    with urllib.request.urlopen(request, timeout=10) as response:
        token = json.load(response)['access_token']
    with open(path, 'rb') as handle:
        body = handle.read()
    request = urllib.request.Request(blob_url, data=body, method='PUT', headers={
        'Authorization': f'Bearer {token}',
        'x-ms-version': '2021-08-06',
        'x-ms-date': now().strftime('%a, %d %b %Y %H:%M:%S GMT'),
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': 'application/gzip',
        'Content-Length': str(len(body)),
    })
    with urllib.request.urlopen(request, timeout=300) as response:
        if response.status != 201:
            raise RuntimeError(f'upload answered {response.status}')


def run():
    container = setting('BACKUP_CONTAINER_URL').rstrip('/')
    if not container.startswith('https://'):
        raise RuntimeError('BACKUP_CONTAINER_URL is not set in ' + DEFAULTS_FILE)
    started = now()
    name = started.strftime('intuneget/%Y/%m/%d/intuneget-%Y%m%dT%H%M%SZ.db.gz')
    with tempfile.TemporaryDirectory() as workdir:
        packed, raw_size, packed_size, sha256 = snapshot(workdir)
        upload(packed, f'{container}/{name}')
    state = {'result': 'success', 'at': now().strftime('%Y-%m-%dT%H:%M:%SZ'), 'blob': name,
             'sizeBytes': raw_size, 'compressedBytes': packed_size, 'sha256': sha256}
    save_state(state)
    print(f'intuneget-backup: uploaded {name} ({packed_size // 1024} KB compressed from {raw_size // 1024} KB)')


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else 'run'
    if command == 'status':
        try:
            with open(STATE_FILE) as handle:
                print(handle.read())
        except OSError:
            print('no backups yet')
        return
    if command != 'run':
        sys.exit(__doc__)
    try:
        run()
    except Exception as error:  # record the failure for the status card and watchdog, then fail the unit
        save_state({'result': 'failed', 'at': now().strftime('%Y-%m-%dT%H:%M:%SZ'), 'error': str(error)[:300]})
        print(f'intuneget-backup: failed: {error}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
