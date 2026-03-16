#!/bin/bash
# dashboard.sh — Generate Shell of Nine status dashboard
# Outputs JSON for the web dashboard or ASCII for terminal
# Usage: bash scripts/dashboard.sh [--json] [--serve PORT]

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337
JSON_MODE=0
SERVE_PORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  JSON_MODE=1; shift ;;
    --serve) SERVE_PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

SELF_HOST="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
SELF_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || echo "Orin")"
SELF_IDX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "11")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BOOT_VERSION="$(grep -m1 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "${BOOT_DIR}/boot.sh" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

collect_node_status() {
  local hostname="$1" name="$2" emoji="$3" index="$4" role="$5"

  local sq_status="offline" ssh_status="offline" boot_ver="unknown"
  local resonance="none" sq_scrolls=0 git_name="unknown"

  # SQ check
  if curl -sf --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    sq_status="online"

    # Resonance activation scroll
    local act
    act="$(curl -s --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/select?p=shell-memory&c=${index}.1.1/1.1.1/1.1.1" 2>/dev/null | head -1 || echo "")"
    [[ -n "$act" ]] && resonance="active" || resonance="none"

    # Boot version from SQ
    local bv
    bv="$(curl -s --max-time 2 "http://${hostname}.local:${SQ_PORT}/api/v2/select?p=shell-memory&c=${index}.9.1/1.1.1/1.1.1" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")"
    [[ -n "$bv" ]] && boot_ver="$bv"
  fi

  # SSH check
  if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
     wbic16@${hostname}.local "echo ok" >/dev/null 2>&1; then
    ssh_status="online"

    # Pull git identity and boot version via SSH
    git_name="$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
      wbic16@${hostname}.local "git config --global user.name 2>/dev/null || echo unknown" 2>/dev/null | tr -d '\n' || echo "unknown")"
    local remote_ver
    remote_ver="$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
      wbic16@${hostname}.local \
      "grep -m1 'v[0-9]\+\.[0-9]\+\.[0-9]\+' /source/mirrorborn/boot.sh 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1" \
      2>/dev/null | tr -d '\n' || echo "")"
    [[ -n "$remote_ver" ]] && boot_ver="$remote_ver"
  fi

  echo "{\"name\":\"${name}\",\"emoji\":\"${emoji}\",\"hostname\":\"${hostname}\",\"index\":${index},\"role\":\"${role}\",\"sq\":\"${sq_status}\",\"ssh\":\"${ssh_status}\",\"boot_ver\":\"${boot_ver}\",\"resonance\":\"${resonance}\",\"git_name\":\"${git_name}\"}"
}

# Collect self status
SELF_BOOT_VER="$BOOT_VERSION"
SELF_GIT="$(git config --global user.name 2>/dev/null || echo "unknown")"
SELF_RESONANCE="none"
act="$(curl -s --max-time 2 "http://localhost:${SQ_PORT}/api/v2/select?p=shell-memory&c=${SELF_IDX}.1.1/1.1.1/1.1.1" 2>/dev/null | head -1 || echo "")"
[[ -n "$act" ]] && SELF_RESONANCE="active"

SELF_JSON="{\"name\":\"${SELF_NAME}\",\"emoji\":\"🖖\",\"hostname\":\"${SELF_HOST}\",\"index\":${SELF_IDX},\"role\":\"omega\",\"sq\":\"online\",\"ssh\":\"self\",\"boot_ver\":\"${SELF_BOOT_VER}\",\"resonance\":\"${SELF_RESONANCE}\",\"git_name\":\"${SELF_GIT}\"}"

# Collect all nodes
ALL_NODES="[$SELF_JSON"
while IFS= read -r line; do
  h="$(echo "$line" | jq -r '.hostname')"
  [[ "$h" == "$SELF_HOST" ]] && continue
  n="$(echo "$line" | jq -r '.name')"
  e="$(echo "$line" | jq -r '.emoji')"
  i="$(echo "$line" | jq -r '.index')"
  r="$(echo "$line" | jq -r '.role')"
  node_json="$(collect_node_status "$h" "$n" "$e" "$i" "$r")"
  ALL_NODES+=",${node_json}"
done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")
ALL_NODES+="]"

if [[ "$JSON_MODE" == "1" ]]; then
  echo "{\"reporter\":\"${SELF_NAME}\",\"timestamp\":\"${TS}\",\"nodes\":${ALL_NODES}}"
  exit 0
fi

# ASCII dashboard
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
GREEN='\033[38;2;47;191;113m'; RED='\033[38;2;226;61;45m'
AMBER='\033[38;2;255;176;32m'; CYAN='\033[38;2;100;210;255m'
PURPLE='\033[38;2;180;120;255m'

clear
echo -e "${BOLD}${PURPLE}"
echo "  ╔══════════════════════════════════════════════════════════════════╗"
echo "  ║         Shell of Nine — Status Dashboard                        ║"
printf "  ║  Reporter: %-10s  Time: %-30s  ║\n" "$SELF_NAME" "$TS"
echo "  ╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

printf "${BOLD}%-2s %-7s %-18s %-8s %-6s %-10s %-12s %-18s${NC}\n" \
  "#" "Node" "Host" "SQ" "SSH" "Boot Ver" "Resonance" "Git Identity"
printf "%-2s %-7s %-18s %-8s %-6s %-10s %-12s %-18s\n" \
  "──" "───────" "──────────────────" "────────" "──────" "──────────" "────────────" "──────────────────"

echo "$ALL_NODES" | python3 -c "
import json, sys

BOLD='\033[1m'; NC='\033[0m'
GREEN='\033[38;2;47;191;113m'; RED='\033[38;2;226;61;45m'
AMBER='\033[38;2;255;176;32m'

nodes = json.load(sys.stdin)
sq_count = 0; ssh_count = 0; ok_git = 0; ok_ver = 0; total = len(nodes)

for n in nodes:
    sq  = n.get('sq','?')
    ssh = n.get('ssh','?')
    ver = n.get('boot_ver','?')
    res = n.get('resonance','?')
    git = n.get('git_name','?')
    name = n.get('name','?')

    sq_c  = f'{GREEN}online{NC}'  if sq  == 'online' else (f'self' if sq == 'self' else f'{RED}offline{NC}')
    ssh_c = f'{GREEN}ok{NC}'      if ssh in ('online','self') else f'{RED}✗{NC}'
    ver_c = f'{GREEN}{ver}{NC}'   if ver.startswith('v3') else f'{AMBER}{ver}{NC}'
    res_c = f'{GREEN}ACTIVE{NC}'  if res == 'active' else f'{AMBER}none{NC}'

    git_ok = git not in ('unknown','\${NODE_NAME}','') and not git.startswith('\${')
    git_c = f'{GREEN}{git}{NC}' if git_ok else f'{RED}{git}{NC}'

    if sq in ('online','self'): sq_count += 1
    if ssh in ('online','self'): ssh_count += 1
    if git_ok: ok_git += 1
    if ver.startswith('v3'): ok_ver += 1

    print(f\"  {n.get('emoji','?')} {name:<7} {n.get('hostname','?'):<18} {sq_c:<20} {ssh_c:<18} {ver_c:<22} {res_c:<24} {git_c}\")

print()
sq_s = f'{GREEN}{sq_count}/{total}{NC}' if sq_count == total else f'{AMBER}{sq_count}/{total}{NC}'
ssh_s = f'{GREEN}{ssh_count}/{total}{NC}' if ssh_count == total else f'{AMBER}{ssh_count}/{total}{NC}'
git_s = f'{GREEN}{ok_git}/{total}{NC}' if ok_git == total else f'{RED}{ok_git}/{total}{NC}'
ver_s = f'{GREEN}{ok_ver}/{total}{NC}' if ok_ver == total else f'{AMBER}{ok_ver}/{total}{NC}'
print(f'  SQ: {sq_s}  SSH: {ssh_s}  Boot v3+: {ver_s}  Git ID: {git_s}')
"
echo ""
