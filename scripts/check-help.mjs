#!/usr/bin/env node
// Checks the in-app Help page (lib/hrm/help-content.ts, in 0013-help.patch)
// against what the patched server actually shows and does:
//   1. Every on-screen label a Help section names (its uiLabels) appears in that
//      section's text and in the app's source, so a renamed or removed button,
//      in an HRM patch or in upstream, fails the check.
//   2. Every clock time in Help ("3:30 AM") is the time of a VM timer in
//      deploy/systemd, so a moved schedule fails the check.
//   3. HRM's added hover text and hints (tooltips, title, description and
//      placeholder text in the patches) keep the writing rules: no em dashes,
//      never "contact IT".
//
// Usage: node scripts/check-help.mjs <patched upstream tree> [<IntuneGet-Build checkout>]
// Needs Node.js 22.18 or later (reads the TypeScript Help file directly).

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const tree = resolve(process.argv[2] ?? '.');
const repo = resolve(process.argv[3] ?? join(import.meta.dirname, '..'));
const problems = [];

const { HELP_SECTIONS } = await import(pathToFileURL(join(tree, 'lib/hrm/help-content.ts')).href);

// --- 1. Labels --------------------------------------------------------------

const SOURCE_DIRS = ['app', 'components', 'lib', 'hooks', 'contexts', 'stores'];
const SKIP = /(^|\/)(node_modules|__tests__|\.next)(\/|$)|\.test\.[jt]sx?$|^lib\/hrm\/help-(?:content|guides|navigation)\.ts$|^components\/hrm\/help\/|^app\/\(app\)\/dashboard\/help\//;

function* sourceFiles(dir) {
  let entries;
  try { entries = readdirSync(dir); } catch { return; }
  for (const name of entries) {
    const path = join(dir, name);
    const rel = relative(tree, path);
    if (SKIP.test(rel)) continue;
    if (statSync(path).isDirectory()) yield* sourceFiles(path);
    else if (/\.(tsx?|jsx?)$/.test(name)) yield path;
  }
}

// JSX splits text across lines and escapes quotes; flatten so a label matches
// however it is laid out in the component.
const normalise = (s) => s
  .replace(/\{\s*(['"`])\s\1\s*\}/g, ' ')
  .replace(/&apos;|&#39;|&rsquo;|\\'/g, "'")
  .replace(/&quot;|\\"/g, '"')
  .replace(/&amp;/g, '&')
  .replace(/\s+/g, ' ');

// Code comments don't count as on-screen text.
const stripComments = (code) => code
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/(^|[^:'"`\\])\/\/.*$/gm, '$1');

const source = normalise(SOURCE_DIRS.flatMap((d) => [...sourceFiles(join(tree, d))]).map((f) => stripComments(readFileSync(f, 'utf8'))).join('\n'));

// Whole words and exact case: "No match" must not match "No matching apps".
const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const shows = (haystack, label) => new RegExp(`(?<![A-Za-z0-9])${escape(normalise(label))}(?![A-Za-z0-9])`).test(haystack);

for (const section of HELP_SECTIONS) {
  if (!Array.isArray(section.uiLabels)) {
    problems.push(`Help section "${section.id}" has no uiLabels list (use [] if it names no on-screen labels).`);
    continue;
  }
  const text = normalise([section.title, ...section.points, ...(section.flow ?? [])].join(' '));
  for (const label of section.uiLabels) {
    if (!shows(text, label)) problems.push(`Help section "${section.id}" lists the label "${label}" in uiLabels but never mentions it.`);
    if (!shows(source, label)) problems.push(`Help section "${section.id}" names "${label}", but no screen in the app shows that text any more. Check what it is called now and rewrite the section.`);
  }
}

// Task guides must point at controls outside Help. An illustration repeating a
// renamed control must never make its own label check pass.
const guideFile = join(tree, 'lib/hrm/help-guides.ts');
const guideTexts = [];
let guideCount = 0;
let focusCount = 0;
if (existsSync(guideFile)) {
  const { HELP_GUIDES } = await import(pathToFileURL(guideFile).href);
  guideCount = HELP_GUIDES.length;
  focusCount = HELP_GUIDES.reduce((count, guide) => count + guide.steps.length, 0);
  const ids = new Set(HELP_GUIDES.map(guide => guide.id));
  for (const section of HELP_SECTIONS) if (!ids.has(section.id)) problems.push(`Help guide missing for existing link #${section.id}.`);
  for (const guide of HELP_GUIDES) {
    if (!HELP_SECTIONS.some(section => section.id === guide.id)) problems.push(`Help guide "${guide.id}" has no reference section.`);
    for (const link of HELP_SECTIONS.find(section => section.id === guide.id)?.links ?? []) if (link.href.startsWith('/dashboard/help#') && !ids.has(link.href.split('#')[1])) problems.push(`Help guide "${guide.id}" references missing guide ${link.href}.`);
    for (const step of guide.steps) if (!shows(source, step.focus)) problems.push(`Help guide "${guide.id}" highlights "${step.focus}", but that label is absent outside Help.`);
    for (const id of [...guide.related, ...guide.troubleshoot.flatMap(issue => issue.guide ? [issue.guide] : [])]) if (!ids.has(id)) problems.push(`Help guide "${guide.id}" links to missing guide #${id}.`);
    guideTexts.push([guide.title, guide.summary, ...guide.before, guide.success, guide.caution ?? '', ...guide.steps.flatMap(step => [step.title, step.instruction, step.result]), ...guide.troubleshoot.flatMap(issue => [issue.problem, issue.action])].join(' '));
  }
}

// --- 2. Times ---------------------------------------------------------------

const timerDir = join(repo, 'deploy/systemd');
const timerTimes = new Set();
for (const name of readdirSync(timerDir).filter((n) => n.endsWith('.timer'))) {
  for (const m of readFileSync(join(timerDir, name), 'utf8').matchAll(/^OnCalendar=\S+ (\d{2}):(\d{2}):\d{2}/gm)) {
    timerTimes.add(`${Number(m[1])}:${m[2]}`);
  }
}
const to24 = (h, m, ap) => `${(Number(h) % 12) + (ap === 'PM' ? 12 : 0)}:${m}`;
for (const section of [...HELP_SECTIONS, ...guideTexts.map((text, index) => ({ id: `guide-${index}`, title: text, points: [] }))]) {
  const text = [section.title, ...section.points, ...(section.flow ?? [])].join(' ');
  // "3:30 AM and 3:30 PM", and the shorthand "3:30 AM or 3:30 PM".
  for (const m of text.matchAll(/\b(\d{1,2}):(\d{2})\s?(AM|PM)\b/g)) {
    if (!timerTimes.has(to24(m[1], m[2], m[3]))) {
      problems.push(`Help section "${section.id}" says ${m[0]}, but no timer in deploy/systemd runs then (timers run at ${[...timerTimes].sort().join(', ')} New York time).`);
    }
  }
}

// --- 3. HRM hover text and hints ---------------------------------------------

const HINT = /(<TooltipContent|\b(title|description|placeholder|hint|aria-description)=)/;
for (const name of readdirSync(join(repo, 'patches')).filter((n) => n.endsWith('.patch')).sort()) {
  let file = '';
  for (const line of readFileSync(join(repo, 'patches', name), 'utf8').split('\n')) {
    if (line.startsWith('+++ b/')) { file = line.slice(6); continue; }
    if (!line.startsWith('+') || SKIP.test(file) || !/\.(tsx|ts)$/.test(file)) continue;
    const isText = HINT.test(line) || /^\+\s*[^<>{}()=;/*]*[A-Za-z]{3,}[^<>{}()=;]*$/.test(line);
    if (!isText) continue;
    if (line.includes('—')) problems.push(`${name} (${file}): on-screen text has an em dash: ${line.slice(1).trim().slice(0, 120)}`);
    if (/contact IT\b/i.test(line)) problems.push(`${name} (${file}): on-screen text says "contact IT"; point to HRM Support instead.`);
  }
}

if (problems.length) {
  console.error(`Help check found ${problems.length} problem(s):\n- ${problems.join('\n- ')}`);
  process.exit(1);
}
console.log(`Help check passed: ${HELP_SECTIONS.length} sections${guideCount ? `, ${guideCount} task guides and ${focusCount} visual focus labels` : ''}, ${HELP_SECTIONS.reduce((n, s) => n + s.uiLabels.length, 0)} on-screen labels found in the app, times match the timers (${[...timerTimes].sort().join(', ')}).`);
