#!/usr/bin/env node
// Finds SQLite migration numbers the way lib/db/sqlite-migrations.ts defines them: each
// migration is an object in the MIGRATIONS list with `version: <number>,`, written either on its
// own line or inline (`{ version: 22, name: ... }`). Only that file counts, so `version: 1` in
// other code (status report, MCP API) is never mistaken for a migration.
//
//   node scripts/migration-numbers.mjs upstream <path to sqlite-migrations.ts>
//   node scripts/migration-numbers.mjs patches <patches dir>
//   node scripts/migration-numbers.mjs check <path to upstream's sqlite-migrations.ts> <patches dir>
//
// upstream and patches print the numbers, sorted and space-separated. check prints one line for
// the weekly upstream check (`ok (...)` or `clash: ...`) and exits 0 either way.
import { readFileSync, readdirSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const MIGRATIONS_FILE = 'lib/db/sqlite-migrations.ts';

// `version: 9,` or `{ version: 22, name`; SQL columns (`version TEXT`) and the type
// (`version: number;`) don't match.
const VERSION = /\bversion:\s*(\d+)\s*,/g;

const sorted = numbers => [...new Set(numbers)].sort((a, b) => a - b);

function versionsIn(text) {
  return [...text.matchAll(VERSION)].map(m => Number(m[1]));
}

/** Migration numbers defined in a sqlite-migrations.ts source. */
export function migrationsInSource(source) {
  return sorted(versionsIn(source));
}

/** Migration numbers a patch adds to lib/db/sqlite-migrations.ts (added lines only). */
export function migrationsInPatch(patch) {
  const found = [];
  let inFile = false;
  for (const line of patch.split('\n')) {
    if (line.startsWith('diff --git ')) {
      inFile = line === `diff --git a/${MIGRATIONS_FILE} b/${MIGRATIONS_FILE}`;
    } else if (inFile && line.startsWith('+') && !line.startsWith('+++')) {
      found.push(...versionsIn(line.slice(1)));
    }
  }
  return sorted(found);
}

export function migrationsInPatchDir(dir) {
  const files = readdirSync(dir).filter(name => name.endsWith('.patch')).sort();
  return sorted(files.flatMap(name => migrationsInPatch(readFileSync(join(dir, name), 'utf8'))));
}

export function verdict(upstream, hrm) {
  const upstreamMax = upstream.length ? Math.max(...upstream) : 0;
  const clash = hrm.filter(n => n <= upstreamMax);
  if (clash.length) return `clash: upstream now goes up to migration ${upstreamMax} and HRM uses ${clash.join(' ')}`;
  return `ok (upstream up to ${upstreamMax}, HRM uses ${hrm.join(' ') || 'none'})`;
}

if (process.argv[1] && realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1])) {
  const [mode, a, b] = process.argv.slice(2);
  if (mode === 'upstream' && a) console.log(migrationsInSource(readFileSync(a, 'utf8')).join(' '));
  else if (mode === 'patches' && a) console.log(migrationsInPatchDir(a).join(' '));
  else if (mode === 'check' && a && b) console.log(verdict(migrationsInSource(readFileSync(a, 'utf8')), migrationsInPatchDir(b)));
  else {
    console.error('Usage: migration-numbers.mjs upstream <sqlite-migrations.ts> | patches <dir> | check <sqlite-migrations.ts> <dir>');
    process.exit(2);
  }
}
