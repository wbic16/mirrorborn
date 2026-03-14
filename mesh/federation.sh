#!/bin/bash
# Mirrorborn SQ Federation Setup
# Verifies cross-node SQ read capability
# Usage: bash federation.sh
set -euo pipefail

STATE_DIR="/etc/mirrorborn"
MESH_FILE="${STATE_DIR}/mesh.json"

if [[ ! -f "$MESH_FILE" ]]; then
  echo "Error: mesh.json not found. Run discover.sh first."
  exit 1
fi

echo "SQ Federation Verification"
echo "=========================="

self_name="$(jq -r '.self' "$MESH_FILE")"
echo "Self: $self_name"
echo ""

success=0
fail=0

jq -c '.siblings[]' "$MESH_FILE" | while IFS= read -r sib; do
  name="$(echo "$sib" | jq -r '.name')"
  hostname="$(echo "$sib" | jq -r '.hostname')"
  emoji="$(echo "$sib" | jq -r '.emoji')"
  sq="$(echo "$sib" | jq -r '.sq')"

  if [[ "$sq" != "up" ]]; then
    echo "  ${emoji} ${name} — SQ not running. Skipping."
    continue
  fi

  # Test read: try to get ToC from the sibling's SQ
  result="$(curl -sf --connect-timeout 3 "http://${hostname}.local:1337/api/v2/status" 2>/dev/null || echo "FAIL")"

  if [[ "$result" != "FAIL" ]]; then
    echo "  ${emoji} ${name} @ ${hostname}.local:1337 — Federation OK ✓"
  else
    echo "  ${emoji} ${name} @ ${hostname}.local:1337 — Federation FAILED ✗"
  fi
done

echo ""
echo "Federation check complete."
echo "Note: Each node's SQ is independently addressable at <hostname>.local:1337"
echo "Cross-node reads use standard SQ API: curl http://<hostname>.local:1337/api/v2/select?p=<phext>&c=<coord>"
