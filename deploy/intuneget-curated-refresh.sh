#!/usr/bin/env bash
# Daily download of upstream's signed curated catalog for HRM's IntuneGet VM.
# Run by intuneget-curated-refresh.timer.
#
# The curated catalog built into an image expires 7 days after upstream signs
# it; upstream re-signs it on its main branch every few days. This saves the
# latest copy next to the app's database, where patch 0011 picks it up. The app
# only uses it if its signature verifies against the keys built into the image
# and it hasn't expired; otherwise it keeps the built-in list. This script only
# checks that the download is a plausible catalog file.
set -euo pipefail

DEFAULTS_FILE=${DEFAULTS_FILE:-/etc/default/intuneget-deploy}
if [ -r "$DEFAULTS_FILE" ]; then set -a; . "$DEFAULTS_FILE"; set +a; fi

DATA_DIR=${DATA_DIR:-/var/lib/docker/volumes/intuneget_intuneget-data/_data}
OUT=${CURATED_CATALOG_FILE:-$DATA_DIR/curated-catalog.json}
SOURCE_URL=${CURATED_CATALOG_URL:-https://raw.githubusercontent.com/ugurkocde/IntuneGet/main/catalog/curated/catalog.json}
MAX_BYTES=$((20 * 1024 * 1024))

log() { echo "intuneget-curated-refresh: $*"; }

tmp=$(mktemp "$(dirname "$OUT")/.curated-catalog.XXXXXX")
trap 'rm -f "$tmp"' EXIT

curl -fsS --proto '=https' --max-time 60 --max-filesize "$MAX_BYTES" -o "$tmp" "$SOURCE_URL"

# A signed envelope: payload with dates and releases, a key id and a signature.
summary=$(python3 -I - "$tmp" <<'PY'
import json, sys
envelope = json.load(open(sys.argv[1]))
payload = envelope['payload']
assert isinstance(envelope['keyId'], str) and isinstance(envelope['signature'], str)
assert isinstance(payload['releases'], list) and payload['generatedAt'] and payload['expiresAt']
print(f"signed {payload['generatedAt']}, expires {payload['expiresAt']}, {len(payload['releases'])} releases")
PY
) || { log "download is not a signed curated catalog; kept the previous file"; exit 1; }

if [ -f "$OUT" ] && cmp -s "$tmp" "$OUT"; then
  log "unchanged ($summary)"
  exit 0
fi
chmod 0644 "$tmp"
mv -f "$tmp" "$OUT"
trap - EXIT
log "saved ($summary)"
