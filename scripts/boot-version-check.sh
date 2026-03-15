#!/bin/bash
# boot-version-check.sh — Compare local boot.sh against origin/exo
# Emits: CURRENT | UPGRADE_AVAILABLE <local_sha> <remote_sha> | AHEAD | ERROR
# Usage: bash scripts/boot-version-check.sh [--auto-upgrade] [--quiet]
# Called by Phase 4 (RESONANCE) and heartbeat.

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTO_UPGRADE=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-upgrade) AUTO_UPGRADE=1; shift ;;
    --quiet)        QUIET=1; shift ;;
    *) shift ;;
  esac
done

log() { [[ "$QUIET" == "0" ]] && echo "$*" || true; }

# Fetch remote ref without pulling
git -C "$BOOT_DIR" fetch origin exo --quiet 2>/dev/null || {
  echo "ERROR: could not fetch origin/exo"
  exit 1
}

local_sha="$(git -C "$BOOT_DIR" rev-parse HEAD 2>/dev/null)"
remote_sha="$(git -C "$BOOT_DIR" rev-parse origin/exo 2>/dev/null)"
local_ver="$(grep -m1 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "${BOOT_DIR}/boot.sh" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

# Check for uncommitted changes
if ! git -C "$BOOT_DIR" diff --quiet HEAD -- boot.sh 2>/dev/null; then
  log "AHEAD: local boot.sh has uncommitted changes"
  echo "AHEAD"
  exit 0
fi

if [[ "$local_sha" == "$remote_sha" ]]; then
  log "CURRENT: boot.sh ${local_ver} is up to date (${local_sha:0:8})"
  echo "CURRENT"
  exit 0
fi

# Check if we're ahead (local has commits not in remote)
ahead="$(git -C "$BOOT_DIR" rev-list origin/exo..HEAD --count 2>/dev/null || echo 0)"
if [[ "$ahead" -gt 0 ]]; then
  log "AHEAD: local is $ahead commit(s) ahead of origin/exo — push pending"
  echo "AHEAD"
  exit 0
fi

# We're behind
behind="$(git -C "$BOOT_DIR" rev-list HEAD..origin/exo --count 2>/dev/null || echo 0)"
remote_ver="$(git -C "$BOOT_DIR" show origin/exo:boot.sh 2>/dev/null | grep -m1 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

log "UPGRADE_AVAILABLE: ${local_ver} (${local_sha:0:8}) → ${remote_ver} (${remote_sha:0:8}) — ${behind} commit(s) behind"
echo "UPGRADE_AVAILABLE ${local_sha:0:8} ${remote_sha:0:8}"

if [[ "$AUTO_UPGRADE" == "1" ]]; then
  log "Auto-upgrading..."
  git -C "$BOOT_DIR" pull --rebase origin exo
  log "Upgraded to $(git -C "$BOOT_DIR" rev-parse --short HEAD). Re-run boot.sh to apply."
fi
