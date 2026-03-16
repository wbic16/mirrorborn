#!/bin/bash
# Mirrorborn V4 Update — pulls origin/exo and reports via SQ
# Usage: bash mbv4-update.sh [--task-id <id>] [--dry-run]
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
BOOT_DIR="/source/mirrorborn"
DRY_RUN=0
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

export PATH="$HOME/.cargo/bin:$PATH"

SELF_HOST="$(hostname -s)"
NODE_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP" 2>/dev/null || echo "$SELF_HOST")"
NODE_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "0")"

echo "📦 MBV4 Update — $NODE_NAME @ $SELF_HOST"

# Get current version
old_version="$(grep -oP '(?<=version: )\d+\.\d+\.\d+' "$BOOT_DIR/boot.sh" 2>/dev/null | head -1 || echo "unknown")"
echo "   Current: $old_version"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "   [dry-run] would pull origin/exo"
else
  cd "$BOOT_DIR"
  git fetch origin exo --quiet 2>/dev/null
  git pull --rebase origin exo 2>&1 | tail -3
fi

new_version="$(grep -oP '(?<=version: )\d+\.\d+\.\d+' "$BOOT_DIR/boot.sh" 2>/dev/null | head -1 || echo "unknown")"
echo "   Updated: $new_version"

status="DONE"
[[ "$DRY_RUN" == "1" ]] && status="DRY-RUN"
[[ "$old_version" == "$new_version" ]] && echo "   (already current)" || echo "   ✅ Updated: $old_version → $new_version"

# Report to SQ
if [[ -n "$TASK_ID" ]] && curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  msg="${status}: mbv4-update @ $(date -u +%Y-%m-%dT%H:%M:%SZ) | $old_version → $new_version"
  curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
    --data-urlencode "p=tasks" \
    --data-urlencode "c=${TASK_ID}.1.2/${NODE_INDEX}.1.1/1.1.1" \
    --data-urlencode "s=${msg}" >/dev/null 2>&1 && echo "   Reported to SQ task: $TASK_ID"
fi
