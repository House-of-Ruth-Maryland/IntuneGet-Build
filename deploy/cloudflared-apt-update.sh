#!/usr/bin/env bash
# Nightly cloudflared update for HRM's IntuneGet VM. Run by cloudflared-update.timer
# through the drop-in in deploy/systemd/cloudflared-update.service.d/.
#
# cloudflared is installed from Cloudflare's apt repository, so its own
# `cloudflared update` refuses to run. This updates the package through apt
# (reading only Cloudflare's list) and restarts the tunnel only when the version
# changed, then checks the tunnel reconnects.
set -euo pipefail

LIST=/etc/apt/sources.list.d/cloudflared.list
READY_URL=${CLOUDFLARED_READY_URL:-http://127.0.0.1:20241/ready}

log() { echo "cloudflared-apt-update: $*"; }
installed() { dpkg-query -W -f='${Version}' cloudflared; }

[ -f "$LIST" ] || { log "$LIST not found; is cloudflared installed from Cloudflare's apt repository?"; exit 1; }

before=$(installed)
apt-get update -qq -o Dir::Etc::sourcelist="$LIST" -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0
# NEEDRESTART_SUSPEND: Ubuntu's needrestart would otherwise offer to restart
# other services (docker among them) after the install. This job restarts only
# the tunnel.
NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --only-upgrade -o DPkg::Lock::Timeout=600 cloudflared
after=$(installed)

if [ "$before" = "$after" ]; then
  log "already current ($after)"
  exit 0
fi

log "updated $before -> $after; restarting the tunnel"
systemctl restart cloudflared
for _ in $(seq 1 24); do
  if curl -sf -o /dev/null "$READY_URL"; then
    log "tunnel connected on $after"
    exit 0
  fi
  sleep 5
done
log "tunnel not ready 120s after the restart; check: journalctl -u cloudflared"
exit 1
