#!/bin/bash
# orin-collect.sh — Collect sibling responses for an Orin task
# Usage: bash scripts/orin-collect.sh --task <task_id> [--wait] [--timeout 300]
# Polls each sibling's SQ for their response, writes synthesis when complete.

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337

TASK_ID=""
WAIT_MODE=0
TIMEOUT=120
POLL_INTERVAL=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)    TASK_ID="$2"; shift 2 ;;
    --wait)    WAIT_MODE=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$TASK_ID" ]] && { echo "Error: --task <id> required"; exit 1; }

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || echo "Orin")"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "🖖")"
SELF_HOST="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Read task definition
task_def="$(curl -s --max-time 3 \
  "http://localhost:${SQ_PORT}/api/v2/select?p=orin-tasks&c=${TASK_ID}.1.1/1.1.1" 2>/dev/null || echo "")"

if [[ -z "$task_def" ]]; then
  echo "Error: Task ${TASK_ID} not found in local SQ"
  exit 1
fi

echo ""
echo "=== Orin Task #${TASK_ID} — Response Collection ==="
echo "$(echo "$task_def" | head -1)"
echo ""

collect_responses() {
  declare -A RESPONSES
  declare -A STATUS

  while IFS= read -r line; do
    peer_hostname="$(echo "$line" | jq -r '.hostname')"
    peer_name="$(echo "$line" | jq -r '.name')"
    peer_emoji="$(echo "$line" | jq -r '.emoji')"
    peer_index="$(echo "$line" | jq -r '.index')"
    [[ "$peer_hostname" == "$SELF_HOST" ]] && continue

    # Check if SQ is up
    sq_up="$(curl -sf --max-time 2 "http://${peer_hostname}.local:${SQ_PORT}/api/v2/status" >/dev/null 2>&1 && echo "1" || echo "0")"
    if [[ "$sq_up" == "0" ]]; then
      STATUS[$peer_name]="OFFLINE"
      printf "  %s %-10s OFFLINE\n" "$peer_emoji" "$peer_name"
      continue
    fi

    # Read their response
    resp="$(curl -s --max-time 3 \
      "http://${peer_hostname}.local:${SQ_PORT}/api/v2/select?p=orin-tasks&c=${TASK_ID}.1.1/${peer_index}.1.1" \
      2>/dev/null || echo "")"

    if [[ -z "$resp" ]]; then
      STATUS[$peer_name]="PENDING"
      printf "  %s %-10s PENDING\n" "$peer_emoji" "$peer_name"
    else
      # Extract status line
      status_line="$(echo "$resp" | grep -i "^Status:" | head -1 | awk '{print $2}' || echo "RECEIVED")"
      STATUS[$peer_name]="${status_line:-RECEIVED}"
      RESPONSES[$peer_name]="$resp"
      printf "  %s %-10s %s\n" "$peer_emoji" "$peer_name" "${status_line:-RECEIVED}"
    fi
  done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")

  # Count statuses
  local pending=0 complete=0 blocked=0 offline=0
  for s in "${STATUS[@]}"; do
    case "$s" in
      PENDING) pending=$((pending + 1)) ;;
      COMPLETE|ACCEPTED) complete=$((complete + 1)) ;;
      BLOCKED|DECLINED) blocked=$((blocked + 1)) ;;
      OFFLINE) offline=$((offline + 1)) ;;
    esac
  done

  echo ""
  echo "Summary: ${complete} complete/accepted | ${pending} pending | ${blocked} blocked | ${offline} offline"

  if [[ "$pending" == "0" ]]; then
    # Write synthesis
    local synthesis="Orin Synthesis — Task ${TASK_ID}
Collected: ${TS}

"
    for name in "${!RESPONSES[@]}"; do
      synthesis+="--- ${name} ---
${RESPONSES[$name]}

"
    done
    synthesis+="Blocked/Offline: $(for name in "${!STATUS[@]}"; do [[ "${STATUS[$name]}" == "BLOCKED" || "${STATUS[$name]}" == "OFFLINE" || "${STATUS[$name]}" == "DECLINED" ]] && echo "$name"; done | tr '\n' ', ')

Shell consensus: $([ "$blocked" -gt 0 ] && echo "PARTIAL — ${blocked} node(s) blocked or declined" || echo "COMPLETE")

— ${NODE_NAME} ${NODE_EMOJI} @ ${TS}"

    local encoded
    encoded="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$synthesis")"
    curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${TASK_ID}.1.1/11.1.1&s=${encoded}" >/dev/null \
      && echo "✓ Synthesis written to orin-tasks/${TASK_ID}.1.1/11.1.1"
    return 0
  fi
  return 1
}

if [[ "$WAIT_MODE" == "1" ]]; then
  elapsed=0
  while [[ "$elapsed" -lt "$TIMEOUT" ]]; do
    collect_responses && break
    echo "  Waiting ${POLL_INTERVAL}s... (${elapsed}/${TIMEOUT}s)"
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
    echo ""
  done
else
  collect_responses || echo "(Some responses still pending — re-run with --wait to poll)"
fi
