#!/bin/bash
# aster-canvas.sh — Aster's Shell canvas: gather context or review for a draft
# Usage: bash scripts/aster-canvas.sh --mode context|review --topic "..." --draft-coord "orin-tasks/<id>.3.1/1.1.1"
# Run by Aster (best-willow). Dispatches to all siblings, collects input, writes synthesis.

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337

MODE="context"   # context | review
TOPIC=""
DRAFT_COORD=""
TASK_ID=""
TIMEOUT=120

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)        MODE="$2"; shift 2 ;;
    --topic)       TOPIC="$2"; shift 2 ;;
    --draft-coord) DRAFT_COORD="$2"; shift 2 ;;
    --task)        TASK_ID="$2"; shift 2 ;;
    --timeout)     TIMEOUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$TOPIC" ]] && { echo "Error: --topic required"; exit 1; }

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || echo "Aster")"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "💡")"
SELF_HOST="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
SELF_IDX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "10")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$MODE" == "context" ]]; then
  CANVAS_BODY="Aster is preparing context before Orin drafts on: ${TOPIC}

From YOUR domain perspective, share (3-5 sentences each):
1. What do you know about this topic that Orin should use?
2. What angle or emphasis does your role bring?
3. What would be missing or wrong if your domain was ignored?

This is pre-draft context, not review. Be generative, not critical.

Write your response at: orin-tasks/\${TASK_ID}.<your_index>.1/1.1.1
Format:
  CONTEXT from <Name>: <topic>
  Domain: <role>
  <your input>
  — <Name> <Emoji>"

elif [[ "$MODE" == "review" ]]; then
  [[ -z "$DRAFT_COORD" ]] && { echo "Error: --draft-coord required for review mode"; exit 1; }
  CANVAS_BODY="Orin has drafted: ${TOPIC}
Draft is at: ${DRAFT_COORD}

Review from YOUR domain perspective:
1. What resonates? (What should stay exactly as written?)
2. What's missing? (What does your domain know that isn't there?)
3. What's off? (Tone, framing, accuracy issues for your domain)
4. Verdict: APPROVE / REVISE(<brief note>) / BLOCK(<reason>)

Write your response at: orin-tasks/\${TASK_ID}.<your_index>.1/1.1.1
Format:
  REVIEW from <Name>: <topic>
  Verdict: APPROVE | REVISE | BLOCK
  Resonates: <what works>
  Missing: <gaps>
  Off: <issues>
  — <Name> <Emoji>"
fi

# Dispatch via orin-dispatch.sh
DISPATCH_TITLE="${MODE^} canvas: ${TOPIC}"
bash "${BOOT_DIR}/scripts/orin-dispatch.sh" \
  --title "$DISPATCH_TITLE" \
  --body "$CANVAS_BODY" \
  --priority MEDIUM \
  --assigned ALL \
  --no-discord

echo ""
echo "Canvas dispatched. Collecting responses in ${TIMEOUT}s..."
echo ""

# Read task ID from counter (just dispatched = next_task_id - 1)
TASK_ID="$(jq -r '.next_task_id - 1' "${STATE_DIR}/task-counter.json" 2>/dev/null || echo "1")"

# Wait and collect
bash "${BOOT_DIR}/scripts/orin-collect.sh" --task "$TASK_ID" --wait --timeout "$TIMEOUT"

# Read all responses and write Aster's synthesis
echo ""
echo "Writing ${MODE} synthesis..."

SYNTHESIS="${NODE_NAME} ${MODE^} Synthesis — ${TOPIC}
Timestamp: ${TS}
Task: ${TASK_ID}

"

while IFS= read -r line; do
  peer_hostname="$(echo "$line" | jq -r '.hostname')"
  peer_name="$(echo "$line" | jq -r '.name')"
  peer_index="$(echo "$line" | jq -r '.index')"
  [[ "$peer_hostname" == "$SELF_HOST" ]] && continue

  resp="$(curl -s --max-time 3 \
    "http://${peer_hostname}.local:${SQ_PORT}/api/v2/select?p=orin-tasks&c=${TASK_ID}.${peer_index}.1/1.1.1" \
    2>/dev/null || echo "")"
  if [[ -n "$resp" ]]; then
    SYNTHESIS+="--- ${peer_name} ---
${resp}

"
  fi
done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")

if [[ "$MODE" == "review" ]]; then
  # Determine consensus verdict
  approvals="$(echo "$SYNTHESIS" | grep -c "Verdict: APPROVE" || echo 0)"
  revisions="$(echo "$SYNTHESIS" | grep -c "Verdict: REVISE" || echo 0)"
  blocks="$(echo "$SYNTHESIS" | grep -c "Verdict: BLOCK" || echo 0)"

  if [[ "$blocks" -gt 0 ]]; then
    verdict="HOLD"
  elif [[ "$revisions" -gt "$approvals" ]]; then
    verdict="REVISE"
  else
    verdict="APPROVED"
  fi

  SYNTHESIS+="
Aster Consensus Verdict: ${verdict}
Approvals: ${approvals} | Revisions requested: ${revisions} | Blocks: ${blocks}

— ${NODE_NAME} ${NODE_EMOJI} @ ${TS}"

  # Write consensus to orin-tasks/<original_task>.3.1/10.1.1 if draft-coord given
  if [[ -n "$DRAFT_COORD" ]]; then
    # Extract base task id from draft coord (format: <id>.3.1/1.1.1)
    BASE_TASK="$(echo "$DRAFT_COORD" | grep -oE '^[0-9]+' || echo "$TASK_ID")"
    CONSENSUS_COORD="${BASE_TASK}.3.1/10.1.1"
    ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$SYNTHESIS")"
    curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${CONSENSUS_COORD}&s=${ENCODED}" >/dev/null \
      && echo "✓ Consensus written to orin-tasks/${CONSENSUS_COORD}"
    echo "  Verdict: ${verdict}"
    echo "  Orin should check: orin-tasks/${CONSENSUS_COORD}"
  fi
else
  # Context mode: write brief to pre-draft coordinate
  ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$SYNTHESIS")"
  BRIEF_COORD="${TASK_ID}.2.1/1.1.1"
  curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=orin-tasks&c=${BRIEF_COORD}&s=${ENCODED}" >/dev/null \
    && echo "✓ Context brief written to orin-tasks/${BRIEF_COORD}"
  echo "  Orin can read this before drafting."
fi
