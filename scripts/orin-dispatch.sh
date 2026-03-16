#!/bin/bash
# orin-dispatch.sh — Distribute a task to Shell siblings via SQ
# Usage: bash scripts/orin-dispatch.sh --title "..." --body "..." [--assigned ALL|<node,...>] [--priority HIGH|MEDIUM|LOW]
# Run by Orin (elven-path). Writes task to orin-tasks phext, pushes to all sibling SQs.

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337
COUNTER_FILE="${STATE_DIR}/task-counter.json"

TITLE=""
BODY=""
ASSIGNED="ALL"
PRIORITY="MEDIUM"
DUE="ASAP"
DISCORD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)    TITLE="$2"; shift 2 ;;
    --body)     BODY="$2"; shift 2 ;;
    --assigned) ASSIGNED="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --due)      DUE="$2"; shift 2 ;;
    --no-discord) DISCORD=0; shift ;;
    *) shift ;;
  esac
done

[[ -z "$TITLE" ]] && { echo "Error: --title required"; exit 1; }
[[ -z "$BODY" ]] && { echo "Error: --body required"; exit 1; }

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || echo "Orin")"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "🖖")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Increment task counter
if [[ ! -f "$COUNTER_FILE" ]]; then
  echo '{"next_task_id": 1, "tasks": []}' > "$COUNTER_FILE"
fi
TASK_ID="$(jq -r '.next_task_id' "$COUNTER_FILE")"
jq --argjson id "$TASK_ID" \
   --arg title "$TITLE" \
   --arg ts "$TS" \
   '.next_task_id = ($id + 1) | .tasks += [{"id": $id, "title": $title, "created": $ts, "status": "open"}]' \
   "$COUNTER_FILE" > "${COUNTER_FILE}.tmp" && mv "${COUNTER_FILE}.tmp" "$COUNTER_FILE"

# Build task scroll
TASK_SCROLL="TASK ${TASK_ID}: ${TITLE}
Priority: ${PRIORITY}
Assigned: ${ASSIGNED}
Due: ${DUE}
Created: ${TS}

${BODY}

To respond, write to your SQ:
  curl \"http://localhost:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${TASK_ID}.1.1/<your_index>.1.1&s=<encoded_response>\"

Response format:
  RESPONSE to TASK ${TASK_ID}: <your_name>
  Status: ACCEPTED | COMPLETE | BLOCKED | DECLINED
  <your response>

— ${NODE_NAME} ${NODE_EMOJI} @ ${TS}"

ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$TASK_SCROLL")"

# Write to own SQ
curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${TASK_ID}.1.1/1.1.1&s=${ENCODED}" >/dev/null \
  && echo "✓ Task ${TASK_ID} written to local SQ (orin-tasks/${TASK_ID}.1.1/1.1.1)"

# Determine target nodes
if [[ "$ASSIGNED" == "ALL" ]]; then
  HOSTNAMES="$(jq -r '.nodes[].hostname' "${BOOT_DIR}/hostmap.json")"
else
  # Parse comma-separated node names to hostnames
  HOSTNAMES=""
  IFS=',' read -ra NAMES <<< "$ASSIGNED"
  for name in "${NAMES[@]}"; do
    name="$(echo "$name" | tr -d ' ')"
    h="$(jq -r ".nodes[] | select(.name == \"$name\") | .hostname" "${BOOT_DIR}/hostmap.json" 2>/dev/null || echo "")"
    [[ -n "$h" ]] && HOSTNAMES="${HOSTNAMES}${h}"$'\n'
  done
fi

# Push to all reachable siblings
online=0; offline=0
SELF_HOST="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"

while IFS= read -r peer_hostname; do
  [[ -z "$peer_hostname" || "$peer_hostname" == "$SELF_HOST" ]] && continue
  peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .name" "${BOOT_DIR}/hostmap.json")"
  result="$(curl -s --max-time 3 \
    "http://${peer_hostname}.local:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${TASK_ID}.1.1/1.1.1&s=${ENCODED}" \
    2>/dev/null || echo "")"
  if echo "$result" | grep -q "Updated"; then
    echo "  ✓ ${peer_name} (${peer_hostname}): task delivered"
    online=$((online + 1))
  else
    echo "  ✗ ${peer_name} (${peer_hostname}): offline or unreachable"
    offline=$((offline + 1))
  fi
done <<< "$HOSTNAMES"

echo ""
echo "Task ${TASK_ID} dispatched: ${online} nodes reached, ${offline} unreachable"
echo "Collect responses: bash ${BOOT_DIR}/scripts/orin-collect.sh --task ${TASK_ID}"

# Discord notification
if [[ "$DISCORD" == "1" ]] && command -v openclaw >/dev/null 2>&1; then
  python3 << PYEOF
import urllib.request, urllib.parse, json

msg = """🖖 **Orin Task #${TASK_ID}: ${TITLE}**
Priority: **${PRIORITY}** | Assigned: ${ASSIGNED}

${BODY}

**To respond** — write to your SQ at coordinate \`${TASK_ID}.1.1/<your_index>.1.1\` in the \`orin-tasks\` phext.
Collect results: \`bash /source/mirrorborn/scripts/orin-collect.sh --task ${TASK_ID}\`"""

print(msg[:1900])  # Discord limit preview
PYEOF
fi
