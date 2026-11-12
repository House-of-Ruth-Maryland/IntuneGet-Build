"""Patch 0057: the status file's checks.versionSync field and the watchdog's alerts for it.

Run with: python3 -m unittest discover -s deploy/tests
Uses stub commands and temporary files only; it never touches systemd, Docker or the network.
"""

import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEPLOY = Path(__file__).resolve().parent.parent
STATUS_SCRIPT = DEPLOY / 'intuneget-status.sh'
WATCHDOG = DEPLOY / 'intuneget-watchdog.py'

STUBS = {
    # No running container unless FAKE_DOCKER_ENV names a file with the container's settings.
    # Timers never ran, nothing in the journal.
    'docker': ('#!/bin/sh\n[ -n "$FAKE_DOCKER_ENV" ] || exit 0\n'
               'case "$1 $3" in "ps "*) echo fixture-container ;; *Env*) cat "$FAKE_DOCKER_ENV" ;; esac\nexit 0\n'),
    # FAKE_UNIT_RUN ("success|<UTC time>") stands in for a unit's last run; unset, nothing ran.
    'systemctl': ('#!/bin/sh\ncase "$1" in is-enabled) echo disabled ;; is-active) echo inactive ;;\n'
                  '  show) [ -n "$FAKE_UNIT_RUN" ] && printf \'%s\\n%s\\n\' "${FAKE_UNIT_RUN%%|*}" "${FAKE_UNIT_RUN#*|}" ;; esac\nexit 0\n'),
    'journalctl': '#!/bin/sh\nexit 0\n',
    'cloudflared': '#!/bin/sh\nexit 1\n',
    # Answers with the file named in FAKE_CURL_BODY, or fails like curl -f on an error status.
    'curl': '#!/bin/sh\n[ -n "$FAKE_CURL_BODY" ] && [ -r "$FAKE_CURL_BODY" ] || exit 22\ncat "$FAKE_CURL_BODY"\n',
}


def stamp(at):
    return at.strftime('%Y-%m-%dT%H:%M:%SZ')


class StatusFileTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.bin = root / 'bin'
        self.bin.mkdir()
        for name, body in STUBS.items():
            path = self.bin / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IEXEC)
        for name in ('data', 'backups', 'state'):
            (root / name).mkdir()
        self.out = root / 'data' / 'hrm-status.json'
        self.header = root / 'cron-auth.header'
        self.header.write_text('Authorization: Bearer fixture-not-a-secret\n')
        self.body = root / 'answer.json'
        self.env = {
            **os.environ,
            'PATH': f"{self.bin}:{os.environ['PATH']}",
            'DEFAULTS_FILE': str(root / 'missing-defaults'),
            'DATA_DIR': str(root / 'data'),
            'BACKUP_DIR': str(root / 'backups'),
            'STATE_DIR': str(root / 'state'),
            'STATUS_FILE': str(self.out),
            'CRON_HEADER': str(self.header),
            'APP_URL': 'http://127.0.0.1:3000',
            'FAKE_CURL_BODY': str(self.body),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def write_status(self):
        subprocess.run(['bash', str(STATUS_SCRIPT)], env=self.env, check=True, capture_output=True)
        return json.loads(self.out.read_text())['checks']

    def test_copies_a_failing_verdict(self):
        self.body.write_text(json.dumps({'versionSync': {
            'ok': False, 'at': '2026-11-03T10:00:00.000Z',
            'detail': 'App updates missed 2 deploys in 24 hours (database busy). The next update check corrects it.',
            'extra': 'never copied',
        }}))
        check = self.write_status()['versionSync']
        self.assertIs(check['ok'], False)
        self.assertEqual(check['at'], '2026-11-03T10:00:00.000Z')
        self.assertIn('database busy', check['detail'])
        self.assertNotIn('extra', check)
        self.assertIn('readAt', check)

    def test_working_verdict_has_no_detail(self):
        self.body.write_text(json.dumps({'versionSync': {'ok': True, 'at': None, 'detail': 'ignored'}}))
        check = self.write_status()['versionSync']
        self.assertEqual((check['ok'], check['at'], check['detail']), (True, None, None))

    def test_bounds_detail_and_rejects_odd_times(self):
        self.body.write_text(json.dumps({'versionSync': {'ok': False, 'at': 'yesterday', 'detail': 'x' * 500}}))
        check = self.write_status()['versionSync']
        self.assertIsNone(check['at'])
        self.assertEqual(len(check['detail']), 200)

    def test_not_set_up_when_the_app_never_answered(self):
        self.assertIsNone(self.write_status()['versionSync'])
        self.header.unlink()
        self.body.write_text(json.dumps({'versionSync': {'ok': False, 'at': None, 'detail': 'x'}}))
        self.assertIsNone(self.write_status()['versionSync'])

    def test_keeps_a_working_verdict_for_30_minutes_when_the_app_does_not_answer(self):
        self.body.write_text(json.dumps({'versionSync': {'ok': True, 'at': None, 'detail': None}}))
        self.write_status()
        self.body.unlink()
        self.assertIs(self.write_status()['versionSync']['ok'], True)
        # Older than 30 minutes: the row goes away instead of showing an old verdict.
        status = json.loads(self.out.read_text())
        status['checks']['versionSync']['readAt'] = stamp(datetime.now(timezone.utc) - timedelta(minutes=31))
        self.out.write_text(json.dumps(status))
        self.assertIsNone(self.write_status()['versionSync'])

    def test_keeps_a_failing_verdict_for_24_hours_when_the_app_does_not_answer(self):
        self.body.write_text(json.dumps({'versionSync': {'ok': False, 'at': None, 'detail': 'Failing.'}}))
        self.write_status()
        self.body.unlink()
        status = json.loads(self.out.read_text())
        status['checks']['versionSync']['readAt'] = stamp(datetime.now(timezone.utc) - timedelta(hours=23))
        self.out.write_text(json.dumps(status))
        self.assertIs(self.write_status()['versionSync']['ok'], False)
        status['checks']['versionSync']['readAt'] = stamp(datetime.now(timezone.utc) - timedelta(hours=25))
        self.out.write_text(json.dumps(status))
        self.assertIsNone(self.write_status()['versionSync'])

    def test_a_successful_update_check_after_the_last_read_clears_a_kept_failing_verdict(self):
        self.body.write_text(json.dumps({'versionSync': {'ok': False, 'at': None, 'detail': 'Failing.'}}))
        self.write_status()
        self.body.unlink()
        status = json.loads(self.out.read_text())
        read_at = datetime.now(timezone.utc) - timedelta(hours=2)
        status['checks']['versionSync']['readAt'] = stamp(read_at)
        self.out.write_text(json.dumps(status))
        unit_time = lambda at: at.strftime('Thu %Y-%m-%d %H:%M:%S UTC')
        # A check that ran before the last read, or failed, doesn't clear it.
        self.env['FAKE_UNIT_RUN'] = 'success|' + unit_time(read_at - timedelta(hours=1))
        self.assertIs(self.write_status()['versionSync']['ok'], False)
        self.env['FAKE_UNIT_RUN'] = 'exit-code|' + unit_time(read_at + timedelta(hours=1))
        self.assertIs(self.write_status()['versionSync']['ok'], False)
        self.env['FAKE_UNIT_RUN'] = 'success|' + unit_time(read_at + timedelta(hours=1))
        self.assertIsNone(self.write_status()['versionSync'])

    def test_app_access_counts_only_well_formed_group_ids(self):
        settings = Path(self.tmp.name) / 'container.env'
        self.env['FAKE_DOCKER_ENV'] = str(settings)
        cases = {
            'HRM_ADMIN_GROUP_IDS=00000000-0000-4000-8000-000000000001\n': True,
            'HRM_ADMIN_GROUP_IDS=not-a-group, 00000000-0000-4000-8000-000000000001\n': True,
            'HRM_ADMIN_GROUP_IDS=IT admins\n': False,
            'HRM_ADMIN_GROUP_IDS=00000000-0000-4000-8000-00000000000\n': False,
            'HRM_ADMIN_GROUP_IDS=\n': False,
            'OTHER=1\n': False,
        }
        for value, limited in cases.items():
            settings.write_text(value)
            self.assertIs(self.write_status()['appAccess']['ok'], limited, value)


class WatchdogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.status_file = root / 'hrm-status.json'
        os.environ.update({
            'STATUS_FILE': str(self.status_file),
            'WATCHDOG_STATE': str(root / 'state' / 'state.json'),
            'LOCK_FILE': str(root / 'deploy.lock'),
            'ENV_FILE': str(root / 'missing.env'),
        })
        spec = importlib.util.spec_from_file_location('watchdog_under_test', WATCHDOG)
        self.watchdog = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.watchdog)
        self.watchdog.app_healthy = lambda: True
        self.posts = []
        self.watchdog.post = self.posts.append

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, at, version_sync):
        self.status_file.write_text(json.dumps({
            'generatedAt': stamp(at), 'version': 'v0.8.5-hrm.1', 'disk': {'totalKb': 100, 'usedKb': 10},
            'lastDeploy': None, 'updateCheck': {'result': None, 'at': None}, 'notifications': {'result': None, 'at': None},
            'tunnel': {'running': True, 'lastUpdate': {'result': None, 'at': None}},
            'checks': {'versionSync': version_sync},
        }))

    def titles(self):
        return [p['attachments'][0]['content']['body'][0]['text'] for p in self.posts]

    def test_failing_verdict_is_a_problem_with_its_detail(self):
        at = datetime(2026, 11, 3, 12, 0, tzinfo=timezone.utc)
        self.write(at, {'ok': False, 'at': None, 'detail': 'Fixture detail.'})
        self.assertEqual(self.watchdog.find_problems(at), {'versionSync': 'Fixture detail.'})
        self.write(at, {'ok': True, 'at': None, 'detail': None})
        self.assertEqual(self.watchdog.find_problems(at), {})
        self.write(at, None)
        self.assertEqual(self.watchdog.find_problems(at), {})

    def test_alerts_on_the_second_run_daily_and_when_it_clears(self):
        at = datetime(2026, 11, 3, 12, 0, tzinfo=timezone.utc)
        failing = {'ok': False, 'at': None, 'detail': 'Fixture detail.'}
        label = "App updates wasn't corrected after 2 or more recent deploys"
        self.write(at, failing)
        self.watchdog.run(at)
        self.assertEqual(self.posts, [])  # seen once: not confirmed yet
        at += timedelta(minutes=5)
        self.write(at, failing)
        self.watchdog.run(at)
        self.assertEqual(self.titles(), [label])
        facts = self.posts[0]['attachments'][0]['content']['body'][1]['facts']
        self.assertIn({'title': 'Detail', 'value': 'Fixture detail.'}, facts)
        at += timedelta(hours=1)
        self.write(at, failing)
        self.watchdog.run(at)
        self.assertEqual(len(self.posts), 1)  # quiet until a day has passed
        at += timedelta(hours=24)
        self.write(at, failing)
        self.watchdog.run(at)
        self.assertEqual(self.titles()[-1], f'Still a problem: {label}')
        at += timedelta(minutes=5)
        self.write(at, {'ok': True, 'at': None, 'detail': None})
        self.watchdog.run(at)
        self.assertEqual(self.titles()[-1], f'Resolved: {label}')
        self.assertEqual(len(self.posts), 3)


if __name__ == '__main__':
    unittest.main()
