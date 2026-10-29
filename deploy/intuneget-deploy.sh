#!/usr/bin/env bash
# Pull-based deploy for HRM's IntuneGet VM. Run by intuneget-deploy.timer.
#
# Reads deploy/version from GitHub: the image tag on the first line and, for
# builds since the digest change, the image digest on the second. A tag that
# no longer points at that digest is refused. When the tag differs from the
# image in the compose override: back up the data volume, switch the image,
# wait for the container to report healthy, and restore the backup and the old image if it
# does not. Going back to an older version restores the backup taken when the
# server last moved off that version, since newer database migrations can't be
# undone in place.
#
#   intuneget-deploy          deploy if deploy/version changed (the timer)
#   intuneget-deploy status   print the last result
#   intuneget-deploy retry    forget a failed version so the next run tries it again
#
# Settings can be overridden in /etc/default/intuneget-deploy.
set -euo pipefail

# Load the VM's settings when run by hand (the systemd unit loads them too).
DEFAULTS_FILE=${DEFAULTS_FILE:-/etc/default/intuneget-deploy}
if [ -r "$DEFAULTS_FILE" ]; then set -a; . "$DEFAULTS_FILE"; set +a; fi

COMPOSE_DIR=${COMPOSE_DIR:-/opt/intuneget}
OVERRIDE_FILE=${OVERRIDE_FILE:-$COMPOSE_DIR/docker-compose.override.yml}
# The compose files read their secrets from this file (docker compose --env-file).
ENV_FILE=${ENV_FILE:-$COMPOSE_DIR/.env.local}
SERVICE=${SERVICE:-web}
# The image to deploy, for example <registry>.azurecr.io/intuneget. Set in
# /etc/default/intuneget-deploy so registry names stay out of this public repo.
IMAGE_REPO=${IMAGE_REPO:?set IMAGE_REPO in /etc/default/intuneget-deploy}
REGISTRY=${IMAGE_REPO%%/*}
VERSION_URL=${VERSION_URL:-https://api.github.com/repos/House-of-Ruth-Maryland/IntuneGet-Build/contents/deploy/version?ref=main}
DATA_DIR=${DATA_DIR:-/var/lib/docker/volumes/intuneget_intuneget-data/_data}
BACKUP_DIR=${BACKUP_DIR:-$COMPOSE_DIR/backups}
KEEP_BACKUPS=${KEEP_BACKUPS:-5}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-300}
# The SQLite database inside DATA_DIR; a backup without it is not a backup.
DB_FILE=${DB_FILE:-intuneget.db}
STATE_DIR=${STATE_DIR:-/var/lib/intuneget-deploy}
LOCK_FILE=${LOCK_FILE:-/run/intuneget-deploy.lock}

TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+-hrm\.[0-9]+$'
DIGEST_PATTERN='^sha256:[0-9a-f]{64}$'

log() { echo "intuneget-deploy: $*"; }

write_status() { # result from to message
  mkdir -p "$STATE_DIR"
  printf '{"time":"%s","result":"%s","from":"%s","to":"%s","message":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$4" > "$STATE_DIR/status.json"
}

compose() {
  [ -f "$ENV_FILE" ] || { log "missing $ENV_FILE; not starting the app without its settings"; return 1; }
  (cd "$COMPOSE_DIR" && docker compose --env-file "$ENV_FILE" "$@")
}

current_tag() {
  sed -nE "s#^[[:space:]]*image:[[:space:]]*${IMAGE_REPO}:([^[:space:]]+)[[:space:]]*\$#\1#p" "$OVERRIDE_FILE" | head -n 1
}

set_tag() { # tag
  local tmp="$OVERRIDE_FILE.tmp"
  sed -E "s#^([[:space:]]*image:[[:space:]]*${IMAGE_REPO}:)[^[:space:]]+#\1$1#" "$OVERRIDE_FILE" > "$tmp"
  mv "$tmp" "$OVERRIDE_FILE"
  [ "$(current_tag)" = "$1" ] || { log "could not set image tag in $OVERRIDE_FILE"; return 1; }
}

# Older-than test for tags like v0.8.1-hrm.3: sort -V orders them correctly.
is_older() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]; }

# Pulls an image tag. For Azure Container Registry, signs in with the VM's
# managed identity (AcrPull): a short-lived registry token, kept in a temporary
# Docker config that is removed after the pull. Tokens go to curl and docker on
# stdin, never as arguments, so they don't show in the process list.
pull_image() { # tag
  local cfg rc aad refresh
  case "$REGISTRY" in *.azurecr.io) ;; *) docker pull -q "$IMAGE_REPO:$1" >/dev/null; return ;; esac
  aad=$(curl -fsS --max-time 20 -H Metadata:true \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" | jq -r .access_token) || return 1
  refresh=$(printf '%s' "$aad" | curl -fsS --max-time 20 -X POST --data-urlencode grant_type=access_token \
    --data-urlencode "service=$REGISTRY" --data-urlencode "access_token@-" \
    "https://$REGISTRY/oauth2/exchange" | jq -r .refresh_token) || return 1
  [ -n "$refresh" ] && [ "$refresh" != null ] || { log "no registry token for $REGISTRY"; return 1; }
  cfg=$(mktemp -d)
  rc=0
  printf '%s' "$refresh" | DOCKER_CONFIG=$cfg docker login "$REGISTRY" -u 00000000-0000-0000-0000-000000000000 --password-stdin >/dev/null &&
    DOCKER_CONFIG=$cfg docker pull -q "$IMAGE_REPO:$1" >/dev/null || rc=1
  rm -rf "$cfg"
  return "$rc"
}

# True when the pulled tag is the image the build recorded (its registry digest).
has_digest() { # tag digest
  docker image inspect -f '{{range .RepoDigests}}{{println .}}{{end}}' "$IMAGE_REPO:$1" 2>/dev/null |
    grep -qxF "$IMAGE_REPO@$2"
}

wait_healthy() {
  local waited=0 id state health
  while [ "$waited" -lt "$HEALTH_TIMEOUT" ]; do
    id=$(compose ps -q "$SERVICE" || true)
    if [ -n "$id" ]; then
      state=$(docker inspect -f '{{.State.Status}}' "$id" 2>/dev/null || echo missing)
      health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id" 2>/dev/null || echo missing)
      [ "$health" = healthy ] && return 0
      case "$state" in exited|dead) log "container $state"; return 1 ;; esac
    fi
    sleep 5
    waited=$((waited + 5))
  done
  log "not healthy after ${HEALTH_TIMEOUT}s"
  return 1
}

# Room for a full copy of the data, twice over, before the app is stopped.
has_backup_space() {
  local need free
  need=$(( $(du -sk "$DATA_DIR" | cut -f1) * 2 ))
  free=$(df -Pk "$BACKUP_DIR" | awk 'NR==2 {print $4}')
  [ -n "$free" ] && [ "$free" -ge "$need" ]
}

# A backup is usable only if it has the database and every data file.
backup_is_complete() { # backup path
  [ -s "$1/data/$DB_FILE" ] && [ -f "$1/docker-compose.override.yml" ] &&
    [ "$(find "$1/data" -type f | wc -l)" -eq "$(find "$DATA_DIR" -type f | wc -l)" ]
}

# Runs inside $(...), where set -e doesn't apply: every step is checked.
backup() { # from-tag; prints the backup path, or fails and leaves nothing behind
  local dest
  dest="$BACKUP_DIR/$(date -u +%Y%m%dT%H%M%SZ)-$$-from-$1"
  if mkdir "$dest" && cp -a "$DATA_DIR" "$dest/data" &&
     cp -a "$OVERRIDE_FILE" "$dest/docker-compose.override.yml" && backup_is_complete "$dest"; then
    echo "$dest"
    return 0
  fi
  rm -rf -- "$dest"
  return 1
}

restore() { # backup path; refuses an incomplete backup
  [ -s "$1/data/$DB_FILE" ] && [ -f "$1/docker-compose.override.yml" ] || { log "backup $1 is incomplete; not restoring"; return 1; }
  rsync -a --delete "$1/data/" "$DATA_DIR/" && cp -a "$1/docker-compose.override.yml" "$OVERRIDE_FILE"
}

prune_backups() {
  local all count
  all=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
  count=$(printf '%s\n' "$all" | grep -c . || true)
  if [ "$count" -gt "$KEEP_BACKUPS" ]; then
    printf '%s\n' "$all" | head -n $((count - KEEP_BACKUPS)) | while read -r old; do rm -rf -- "$old"; done
  fi
}

prune_images() { # keep these tags
  docker image ls "$IMAGE_REPO" --format '{{.Tag}}' | while read -r tag; do
    case " $* " in *" $tag "*) ;; *) docker image rm "$IMAGE_REPO:$tag" >/dev/null 2>&1 || true ;; esac
  done
}

deploy() {
  local desired digest version current target_backup="" dest
  version=$(curl -fsS --max-time 20 -H 'Accept: application/vnd.github.raw' "$VERSION_URL")
  desired=$(printf '%s\n' "$version" | sed -n 1p | tr -d '[:space:]')
  digest=$(printf '%s\n' "$version" | sed -n 2p | tr -d '[:space:]')
  if ! [[ "$desired" =~ $TAG_PATTERN ]]; then
    log "deploy/version is not a valid tag: '$desired'"
    return 1
  fi
  if [ -n "$digest" ] && ! [[ "$digest" =~ $DIGEST_PATTERN ]]; then
    log "deploy/version has an invalid digest: '$digest'"
    return 1
  fi
  current=$(current_tag)
  if [ -z "$current" ]; then
    log "no $IMAGE_REPO image line in $OVERRIDE_FILE"
    return 1
  fi
  [ "$desired" = "$current" ] && return 0
  if [ "$(cat "$STATE_DIR/failed" 2>/dev/null || true)" = "$desired" ]; then
    return 0 # already failed and rolled back; run 'intuneget-deploy retry' to try again
  fi

  if is_older "$desired" "$current"; then
    target_backup=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name "*-from-$desired" | sort | tail -n 1)
    if [ -z "$target_backup" ]; then
      log "no backup from $desired to go back to; not changing anything"
      write_status refused "$current" "$desired" "no backup from $desired"
      echo "$desired" > "$STATE_DIR/failed"
      return 1
    fi
  fi

  if ! pull_image "$desired"; then
    log "$IMAGE_REPO:$desired is not available yet; will try again"
    write_status waiting "$current" "$desired" "image not available yet"
    return 0
  fi
  if [ -n "$digest" ] && ! has_digest "$desired" "$digest"; then
    log "$IMAGE_REPO:$desired is not the image the build recorded ($digest); not deploying"
    write_status refused "$current" "$desired" "image digest does not match deploy/version"
    echo "$desired" > "$STATE_DIR/failed"
    return 1
  fi

  if ! has_backup_space; then
    log "not enough free disk space for a backup; not changing anything"
    write_status refused "$current" "$desired" "not enough disk space for a backup"
    echo "$desired" > "$STATE_DIR/failed"
    return 1
  fi

  log "deploying $desired (was $current)"
  compose stop "$SERVICE"
  if ! dest=$(backup "$current"); then
    log "backup failed; starting $current again and not deploying"
    echo "$desired" > "$STATE_DIR/failed"
    compose up -d "$SERVICE" || true
    write_status backup_failed "$current" "$desired" "backup failed; nothing changed"
    return 1
  fi
  log "backup saved to $dest"

  [ -z "$target_backup" ] || log "going back to an older version: restoring $target_backup"
  if { [ -z "$target_backup" ] || { [ -s "$target_backup/data/$DB_FILE" ] && rsync -a --delete "$target_backup/data/" "$DATA_DIR/"; }; } &&
     set_tag "$desired" && compose up -d "$SERVICE" && wait_healthy; then
    log "$desired is healthy"
    write_status deployed "$current" "$desired" "backup $dest"
    rm -f "$STATE_DIR/failed"
    prune_backups
    prune_images "$desired" "$current"
    return 0
  fi

  log "$desired failed; rolling back to $current"
  echo "$desired" > "$STATE_DIR/failed"
  compose stop "$SERVICE" || true
  # The previous image is normally still on the VM; fetch it again if it was removed.
  docker image inspect "$IMAGE_REPO:$current" >/dev/null 2>&1 || pull_image "$current" || true
  if restore "$dest" && compose up -d "$SERVICE" && wait_healthy; then
    write_status rolled_back "$current" "$desired" "restored $dest"
  else
    write_status rollback_failed "$current" "$desired" "restore $dest by hand"
  fi
  return 1
}

main() {
  mkdir -p "$STATE_DIR" "$BACKUP_DIR"
  case "${1:-run}" in
    run)
      exec 9>"$LOCK_FILE"
      flock -n 9 || { log "another deploy is running"; return 0; }
      deploy
      ;;
    status) cat "$STATE_DIR/status.json" 2>/dev/null || echo "no deploys yet" ;;
    retry) rm -f "$STATE_DIR/failed"; log "the next run will try again" ;;
    *) echo "usage: intuneget-deploy [run|status|retry]" >&2; return 2 ;;
  esac
}

main "$@"
