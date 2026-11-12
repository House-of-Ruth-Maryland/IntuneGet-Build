#!/usr/bin/env bash
# Validate an already-patched tree with dependencies installed. Never builds or deploys.
set -euo pipefail

usage() {
  echo "Usage: $0 <patched-tree> [full | related <source-file> ...]" >&2
  exit 2
}
[ "$#" -ge 1 ] || usage
patched_tree=$(cd -- "$1" && pwd -P)
shift
mode=${1:-full}
[ "$#" -eq 0 ] || shift
case "$mode" in
  full) [ "$#" -eq 0 ] || usage ;;
  related) [ "$#" -gt 0 ] || usage ;;
  *) usage ;;
esac
build_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$patched_tree"
[ -f package.json ] && [ -f packager/tsconfig.json ] || { echo 'Choose a patched IntuneGet tree.' >&2; exit 2; }
[ -d node_modules ] && [ -d packager/node_modules ] || { echo 'Install app and packager dependencies first; see README.md.' >&2; exit 2; }
# Give filesystem fixtures one private, canonical scratch directory. On macOS,
# /tmp avoids Spotlight indexing thousands of disposable database fixture files.
temporary_base=$(node -p "require('node:fs').realpathSync(process.platform === 'darwin' ? '/tmp' : require('node:os').tmpdir())")
temporary_root=$(mktemp -d "$temporary_base/intuneget-check.XXXXXXXX")
trap 'rm -rf -- "$temporary_root"' EXIT
export TMPDIR="$temporary_root"
node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON "$build_repo/scripts/check-help.mjs" "$patched_tree" "$build_repo"
if [ "$mode" = related ]; then
  # Keep per-file isolation. Related tests are for iteration, not release sign-off.
  npm exec -- vitest related --run "$@"
else
  node --test "$build_repo/scripts/check-help.test.mjs"
  # VM status script and watchdog checks (stub commands only; patch 0057).
  python3 -m unittest discover -s "$build_repo/deploy/tests"
  npm exec -- tsc --noEmit -p .
  (cd packager && npm exec -- tsc --noEmit -p .)
  npm test
fi
