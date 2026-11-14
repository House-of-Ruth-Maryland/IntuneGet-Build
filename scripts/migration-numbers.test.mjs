import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { migrationsInPatch, migrationsInPatchDir, migrationsInSource, verdict } from './migration-numbers.mjs';

const patch = (file, body) => `diff --git a/${file} b/${file}
index 1111111..2222222 100644
--- a/${file}
+++ b/${file}
@@ -1,3 +1,9 @@
${body}
`;

test('finds migrations written on their own line and inline', () => {
  const text = patch('lib/db/sqlite-migrations.ts', [
    '   },',
    '+  {',
    '+    version: 9,',
    "+    name: 'webhook configurations',",
    "+  { version: 22, name: 'startup reports', up: db => {",
    '+  {version:23,name:"pause"},',
  ].join('\n'));
  assert.deepEqual(migrationsInPatch(text), [9, 22, 23]);
});

test('ignores other files, removed and context lines, SQL columns and the type', () => {
  const text = [
    patch('lib/hrm/status-report.ts', '+    version: 1,\n+  { version: 1, generatedAt }'),
    patch('lib/db/sqlite-migrations.ts', [
      '     version: 8,',
      '-    version: 30,',
      '+          version TEXT NOT NULL,',
      '+  version: number;',
      '+    version: 10,',
    ].join('\n')),
    patch('lib/hrm/mcp-api.ts', '+  version: 1,'),
  ].join('');
  assert.deepEqual(migrationsInPatch(text), [10]);
});

test("reads upstream's migration list", () => {
  const source = `export interface Migration {\n  version: number;\n}\nconst MIGRATIONS = [\n  {\n    version: 1,\n    name: 'a',\n    up: db => db.exec('CREATE TABLE t (version TEXT NOT NULL)'),\n  },\n  { version: 2, name: 'b', up: () => {} },\n];\n`;
  assert.deepEqual(migrationsInSource(source), [1, 2]);
});

test('reports a clash only when HRM uses a number upstream has reached', () => {
  assert.equal(verdict([1, 2, 8], [9, 10]), 'ok (upstream up to 8, HRM uses 9 10)');
  assert.equal(verdict([1, 9, 10], [9, 10, 11]), 'clash: upstream now goes up to migration 10 and HRM uses 9 10');
  assert.equal(verdict([1], []), 'ok (upstream up to 1, HRM uses none)');
});

test("this repo's patches add HRM migrations 9 upwards with no gaps", () => {
  const found = migrationsInPatchDir(fileURLToPath(new URL('../patches', import.meta.url)));
  assert.ok(found.length >= 16, `expected at least 9 to 24, got ${found.join(' ')}`);
  assert.deepEqual(found, Array.from({ length: found.length }, (_, i) => 9 + i));
});
