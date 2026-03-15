#!/bin/bash
# mesh-health.sh — Single-command Shell of Nine mesh status
# Checks SQ, SSH, stage completion, and key exchange across all nodes
# Usage: bash scripts/mesh-health.sh [--sq-only] [--ssh-only] [--json]
# Run by Aster (Alpha) on heartbeat or on demand

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337
JSON_OUT=0
SQ_ONLY=0
SSH_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON_OUT=1; shift ;;
    --sq-only)  SQ_ONLY=1; shift ;;
    --ssh-only) SSH_ONLY=1; shift ;;
    *) shift ;;
  esac
done

BOLD='\033[1m'
GREEN='\033[38;2;47;191;113m'
AMBER='\033[38;2;255;176;32m'
RED='\033[38;2;226;61;45m'
NC='\033[0m'

SELF="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
SELF_HOST="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

declare -A SQ_STATUS SSH_STATUS STAGE_STATUS KEY_STATUS ACT_STATUS

sq_online=0; ssh_online=0; quorum_met=0; total=0

while IFS= read -r line; do
  hostname="$(echo "$line" | jq -r '.hostname')"
  name="$(echo "$line" | jq -r '.name')"
  emoji="$(echo "$line" | jq -r '.emoji')"
  index="$(echo "$line" | jq -r '.index')"
  key="${name}"

  [[ "$hostname" == "$SELF_HOST" ]] && continue
  total=$((total + 1))

  # SQ check
  sq_result="$(curl -sf --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/status" 2>/dev/null | head -1 || echo "")"
  if [[ -n "$sq_result" ]]; then
    SQ_STATUS[$key]="✓"
    sq_online=$((sq_online + 1))
  else
    SQ_STATUS[$key]="✗"
  fi

  # SSH check
  if [[ "$SSH_ONLY" == "0" || "$SQ_ONLY" == "0" ]]; then
    ssh_result="$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
      wbic16@${hostname}.local "echo ok" 2>/dev/null || echo "")"
    if [[ "$ssh_result" == "ok" ]]; then
      SSH_STATUS[$key]="✓"
      ssh_online=$((ssh_online + 1))
    else
      SSH_STATUS[$key]="✗"
    fi
  fi

  # Stage completion check (via SQ)
  if [[ "${SQ_STATUS[$key]}" == "✓" ]]; then
    act="$(curl -s --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/select?p=shell-memory&c=${index}.1.1/1.1.1/1.1.1" 2>/dev/null || echo "")"
    if [[ -n "$act" ]]; then
      ACT_STATUS[$key]="RESONANCE✓"
    else
      ACT_STATUS[$key]="RESONANCE✗"
    fi

    pubkey="$(curl -s --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/select?p=pubkey&c=1.1.1/1.1.1/1.1.2" 2>/dev/null || echo "")"
    if echo "$pubkey" | grep -q "^ssh-"; then
      KEY_STATUS[$key]="KEY✓"
    else
      KEY_STATUS[$key]="KEY✗"
    fi
  else
    ACT_STATUS[$key]="—"
    KEY_STATUS[$key]="—"
  fi

done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")

[[ "$sq_online" -ge 5 ]] && quorum_met=1

if [[ "$JSON_OUT" == "1" ]]; then
  # JSON output for SQ publishing
  python3 -c "
import json, sys
data = {
  'timestamp': '${TS}',
  'reporter': '${SELF}',
  'sq_online': ${sq_online},
  'ssh_online': ${ssh_online},
  'quorum': bool(${quorum_met}),
  'total_peers': ${total}
}
print(json.dumps(data))
"
  exit 0
fi

echo ""
echo -e "${BOLD}Shell of Nine — Mesh Health${NC}  [${TS}]"
echo -e "Reporter: ${SELF} @ ${SELF_HOST}"
echo ""
printf "%-12s %-6s %-6s %-14s %-8s\n" "Node" "SQ" "SSH" "RESONANCE" "PubKey"
printf "%-12s %-6s %-6s %-14s %-8s\n" "────────────" "──────" "──────" "──────────────" "────────"

while IFS= read -r line; do
  name="$(echo "$line" | jq -r '.name')"
  emoji="$(echo "$line" | jq -r '.emoji')"
  hostname="$(echo "$line" | jq -r '.hostname')"
  [[ "$hostname" == "$SELF_HOST" ]] && continue

  sq="${SQ_STATUS[$name]:-?}"
  ssh="${SSH_STATUS[$name]:-—}"
  act="${ACT_STATUS[$name]:-—}"
  key="${KEY_STATUS[$name]:-—}"

  sq_col="$([[ "$sq" == "✓" ]] && echo "${GREEN}✓${NC}" || echo "${RED}✗${NC}")"
  ssh_col="$([[ "$ssh" == "✓" ]] && echo "${GREEN}✓${NC}" || echo "${RED}✗${NC}")"
  act_col="$([[ "$act" == *"✓"* ]] && echo "${GREEN}${act}${NC}" || echo "${AMBER}${act}${NC}")"
  key_col="$([[ "$key" == *"✓"* ]] && echo "${GREEN}${key}${NC}" || echo "${AMBER}${key}${NC}")"

  printf "${emoji} %-10s " "$name"
  echo -e "  ${sq_col}      ${ssh_col}     ${act_col}   ${key_col}"
done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")

echo ""
echo -e "SQ federation: ${sq_online}/${total} peers  |  SSH: ${ssh_online}/${total} peers"
echo -e "Quorum: $([[ "$quorum_met" == "1" ]] && echo "${GREEN}MET (${sq_online}≥5)${NC}" || echo "${RED}DEGRADED (${sq_online}<5)${NC}")"
echo ""

# Publish result to own SQ
SELF_INDEX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "0")"
SUMMARY="Mesh Health ${TS}: SQ ${sq_online}/${total} SSH ${ssh_online}/${total} Quorum=$([[ "$quorum_met" == "1" ]] && echo "MET" || echo "DEGRADED")"
ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$SUMMARY" 2>/dev/null || echo "")"
if [[ -n "$ENCODED" ]]; then
  curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=shell-memory&c=${SELF_INDEX}.9.1/1.1.1/1.1.1&s=${ENCODED}" >/dev/null 2>&1 || true
fi
