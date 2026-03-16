#!/bin/bash
# Mirrorborn Orchestrator — Orin-class SQ task distribution
# Usage: bash orchestrate.sh <task_id> <description> [--poll] [--wait]
# Examples:
#   bash orchestrate.sh mbv4-update "Pull origin/exo and run boot-version-check"
#   bash orchestrate.sh git-fix "Fix git user.name/email; amend broken commits"
#   bash orchestrate.sh mbv4-update --poll
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
TASK_ID="${1:-}"
TASK_DESC="${2:-}"
POLL_ONLY=0
WAIT_SEC=0

[[ "$*" == *"--poll"* ]] && POLL_ONLY=1
[[ "$*" =~ --wait[[:space:]]+([0-9]+) ]] && WAIT_SEC="${BASH_REMATCH[1]}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: bash orchestrate.sh <task_id> [description] [--poll] [--wait N]"
  echo "Task IDs: mbv4-update | git-fix | ssh-exchange | sq-start | retro | mesh-health"
  exit 1
fi

SELF_HOST="$(hostname -s)"
SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP" 2>/dev/null || echo "$SELF_HOST")"
SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "0")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

export PATH="$HOME/.cargo/bin:$PATH"

# ── Assign task ───────────────────────────────────────────────────────────────
if [[ "$POLL_ONLY" == "0" ]]; then
  echo ""
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║     ORCHESTRATOR — TASK DISPATCH     ║"
  echo "  ╚══════════════════════════════════════╝"
  echo "  Task:  $TASK_ID"
  echo "  Desc:  ${TASK_DESC:-<no description>}"
  echo "  From:  $SELF_NAME @ $SELF_HOST"
  echo "  Time:  $TS"
  echo ""

  all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"
  assigned=0
  skipped=0

  while IFS= read -r node; do
    [[ "$node" == "$SELF_HOST" ]] && continue
    idx="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .index" "$HOSTMAP")"
    name="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .name" "$HOSTMAP")"
    emoji="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .emoji" "$HOSTMAP")"

    sq_up="$(curl -sf --connect-timeout 2 "http://${node}.local:${SQ_PORT}/api/v2/status" 2>/dev/null && echo "up" || echo "down")"

    if [[ "$sq_up" == "up" ]]; then
      curl -sf -G "http://${node}.local:${SQ_PORT}/api/v2/update" \
        --data-urlencode "p=tasks" \
        --data-urlencode "c=${TASK_ID}.1.1/${idx}.1.1/1.1.1" \
        --data-urlencode "s=ASSIGNED|${TASK_DESC}|from:${SELF_NAME}|ts:${TS}" \
        >/dev/null 2>&1 && echo "  ✅ $emoji $name ($node): assigned" || echo "  ⚠️  $emoji $name: SQ write failed"
      assigned=$((assigned + 1))
    else
      echo "  ⏭  $emoji $name ($node): offline"
      skipped=$((skipped + 1))
    fi
  done <<< "$all_hostnames"

  # Write task to own SQ for record
  curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
    --data-urlencode "p=tasks" \
    --data-urlencode "c=${TASK_ID}.1.3/1.1.1/1.1.1" \
    --data-urlencode "s=DISPATCHED|assigned:${assigned}|skipped:${skipped}|ts:${TS}" \
    >/dev/null 2>&1 || true

  echo ""
  echo "  Assigned: $assigned nodes | Skipped (offline): $skipped nodes"
  echo ""

  [[ "$WAIT_SEC" -gt 0 ]] && { echo "  Waiting ${WAIT_SEC}s for responses..."; sleep "$WAIT_SEC"; }
fi

# ── Poll responses ────────────────────────────────────────────────────────────
echo "  Polling responses for task: $TASK_ID"
echo "  ──────────────────────────────────────"

done_count=0
fail_count=0
pending_count=0
all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"

while IFS= read -r node; do
  [[ "$node" == "$SELF_HOST" ]] && continue
  idx="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .index" "$HOSTMAP")"
  name="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .name" "$HOSTMAP")"
  emoji="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .emoji" "$HOSTMAP")"

  response="$(curl -sf --connect-timeout 2 \
    "http://${node}.local:${SQ_PORT}/api/v2/select?p=tasks&c=${TASK_ID}.1.2/${idx}.1.1/1.1.1" \
    2>/dev/null || echo "")"

  if [[ "$response" == DONE* ]]; then
    echo "  ✅ $emoji $name: $response"
    done_count=$((done_count + 1))
  elif [[ "$response" == FAILED* ]]; then
    echo "  ❌ $emoji $name: $response"
    fail_count=$((fail_count + 1))
  elif [[ -n "$response" ]]; then
    echo "  🔄 $emoji $name: $response"
    pending_count=$((pending_count + 1))
  else
    echo "  ⏳ $emoji $name: no response"
    pending_count=$((pending_count + 1))
  fi
done <<< "$all_hostnames"

echo ""
echo "  Done: $done_count | Failed: $fail_count | Pending: $pending_count"
echo ""
