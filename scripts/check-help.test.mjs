import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
function check({ actual = 'Example control', related = [] } = {}) {
  const tree = mkdtempSync(path.join(tmpdir(), 'help-label-check-'));
  try {
    for (const directory of ['lib/hrm', 'components/hrm/help']) mkdirSync(path.join(tree, directory), { recursive: true });
    const section = { id: 'example', title: 'Example task', points: ['Use Example control.'], uiLabels: ['Example control'] };
    const guide = { id: 'example', title: 'Example task', summary: 'Do the task.', before: [], success: 'Review the result.', steps: [{ title: 'Choose it', instruction: 'Choose the control.', result: 'A review opens.', focus: 'Example control' }], related, troubleshoot: [] };
    writeFileSync(path.join(tree, 'lib/hrm/help-content.ts'), `export const HELP_SECTIONS=${JSON.stringify([section])};`);
    writeFileSync(path.join(tree, 'lib/hrm/help-guides.ts'), `export const HELP_GUIDES=${JSON.stringify([guide])};`);
    writeFileSync(path.join(tree, 'components/Screen.tsx'), `export const Screen=()=> <button>${actual}</button>;`);
    // The reference repeats the old label even when the actual control changes.
    writeFileSync(path.join(tree, 'components/hrm/help/HelpVisual.tsx'), 'export const Illustration=()=> <span>Example control</span>;');
    return spawnSync(process.execPath, ['--disable-warning=MODULE_TYPELESS_PACKAGE_JSON', path.join(repo, 'scripts/check-help.mjs'), tree, repo], { encoding: 'utf8', timeout: 10000 });
  } finally { rmSync(tree, { recursive: true, force: true }); }
}

test('accepts a guide whose control exists in the actual UI', () => {
  const result = check(); assert.equal(result.status, 0, result.stderr);
});
test('a stale illustration cannot make a renamed actual control pass', () => {
  const result = check({ actual: 'Renamed control' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /absent outside Help/);
});
test('rejects a related-guide link that leads nowhere', () => {
  const result = check({ related: ['missing-guide'] });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /missing guide #missing-guide/);
});
