#!/bin/bash
# Mirrorborn Boot Version Check
# Compares local boot.sh version against origin/exo
# Usage: bash boot-version-check.sh [--auto-upgrade]
# Outputs: CURRENT | UPGRADE_AVAILABLE <old> <new> | AHEAD | ERROR
set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOT_SCRIPT="${BOOT_DIR}/boot.sh"
AUTO_UPGRADE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-upgrade) AUTO_UPGRADE=1; shift ;;
    *) shift ;;
  esac
done

# Extract version from local boot.sh
local_version="$(grep -oP '(?<=version: )\d+\.\d+\.\d+' "$BOOT_SCRIPT" 2>/dev/null | head -1 || echo "unknown")"

# Fetch remote version without checkout
if ! git -C "$BOOT_DIR" fetch origin exo --quiet 2>/dev/null; then
  echo "ERROR: cannot reach origin"
  exit 0
fi

remote_version="$(git -C "$BOOT_DIR" show origin/exo:boot.sh 2>/dev/null | \
  grep -oP '(?<=version: )\d+\.\d+\.\d+' | head -1 || echo "unknown")"

if [[ "$local_version" == "unknown" || "$remote_version" == "unknown" ]]; then
  echo "ERROR: version parse failed (local=$local_version remote=$remote_version)"
  exit 0
fi

# Compare using sort -V
higher="$(printf '%s\n%s\n' "$local_version" "$remote_version" | sort -V | tail -1)"

if [[ "$local_version" == "$remote_version" ]]; then
  echo "CURRENT $local_version"
elif [[ "$higher" == "$remote_version" ]]; then
  echo "UPGRADE_AVAILABLE $local_version $remote_version"
  if [[ "$AUTO_UPGRADE" == "1" ]]; then
    echo "Auto-upgrading boot.sh from $local_version → $remote_version..."
    git -C "$BOOT_DIR" pull --rebase origin exo
    echo "Upgraded. Re-run boot.sh to apply."
  fi
else
  echo "AHEAD $local_version (remote: $remote_version)"
fi
