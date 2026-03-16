#!/bin/bash
# Mirrorborn Service Uptime Monitor
# Checks all core services on all nodes, restarts where possible via SSH,
# files GitHub issues for persistent failures (requires GH_TOKEN or gh auth)
# Usage: bash uptime-monitor.sh [--file-issues] [--auto-restart]
# Run via cron: */5 * * * * bash /source/mirrorborn/scripts/uptime-monitor.sh --auto-restart
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
FILE_ISSUES=0
AUTO_RESTART=0
STATE_DIR="/tmp/mirrorborn-uptime"
ISSUE_REPO="wbic16/mirrorborn"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-issues)   FILE_ISSUES=1; shift ;;
    --auto-restart)  AUTO_RESTART=1; shift ;;
    *) shift ;;
  esac
done

export PATH="$HOME/.cargo/bin:$PATH"
mkdir -p "$STATE_DIR"

SELF_HOST="$(hostname -s)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"

# Services to check per node
# Format: name|check_cmd|restart_cmd
declare -a SERVICES=(
  "sq|curl -sf --connect-timeout 2 http://NODE_HOST.local:${SQ_PORT}/api/v2/status >/dev/null 2>&1|nohup sq host ${SQ_PORT} > /tmp/sq.log 2>&1 &"
  "openclaw|pgrep -f 'openclaw.*gateway' >/dev/null 2>&1|openclaw gateway restart"
)

issues_filed=0
restarts=0

all_hostnames="$(jq -r '.nodes[] | select(.status // "online" != "offline") | .hostname' "$HOSTMAP" 2>/dev/null || jq -r '.nodes[].hostname' "$HOSTMAP")"

while IFS= read -r node; do
  [[ "$node" == "$SELF_HOST" ]] && continue

  node_name="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .name" "$HOSTMAP")"
  node_emoji="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .emoji" "$HOSTMAP")"
  node_idx="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .index" "$HOSTMAP")"

  # Check if node is offline (scheduled)
  offline_until="$(jq -r ".nodes[] | select(.hostname == \"$node\") | .offline_until // \"\"" "$HOSTMAP" 2>/dev/null || echo "")"
  if [[ -n "$offline_until" ]]; then
    echo "  ⏸  $node_emoji $node_name: scheduled offline until $offline_until — skipping"
    continue
  fi

  # Ping check
  if ! ping -c 1 -W 2 "${node}.local" >/dev/null 2>&1; then
    echo "  ❌ $node_emoji $node_name ($node): unreachable by ping"
    _file_issue "$node" "$node_name" "$node_emoji" "ping" "unreachable" "" "$FILE_ISSUES" "$ISSUE_REPO" "$TS"
    continue
  fi

  # SQ check
  sq_ok=0
  sq_raw="$(curl -sf --connect-timeout 2 "http://${node}.local:${SQ_PORT}/api/v2/status" 2>/dev/null || echo "")"
  [[ -n "$sq_raw" ]] && sq_ok=1

  if [[ "$sq_ok" == "0" ]]; then
    echo "  ⚠️  $node_emoji $node_name: SQ offline"

    if [[ "$AUTO_RESTART" == "1" ]]; then
      # Try SSH restart
      ssh_ok="$(ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
        "${REAL_USER}@${node}.local" "echo ok" 2>/dev/null || echo "")"
      if [[ "$ssh_ok" == "ok" ]]; then
        ssh -o StrictHostKeyChecking=no "${REAL_USER}@${node}.local" \
          "export PATH=\$HOME/.cargo/bin:\$PATH; curl -sf http://localhost:${SQ_PORT}/api/v2/status >/dev/null 2>&1 || (nohup sq host ${SQ_PORT} > /tmp/sq.log 2>&1 & sleep 2 && curl -sf http://localhost:${SQ_PORT}/api/v2/status >/dev/null 2>&1 && echo 'SQ restarted' || echo 'SQ restart failed')" \
          2>/dev/null && restarts=$((restarts+1)) || true
        echo "     → restart attempted via SSH"
      fi
    fi

    # Track failure duration
    fail_file="${STATE_DIR}/${node}-sq-fail"
    if [[ ! -f "$fail_file" ]]; then
      echo "$TS" > "$fail_file"
    else
      fail_since="$(cat "$fail_file")"
      fail_mins=$(( ($(date +%s) - $(date -d "$fail_since" +%s 2>/dev/null || echo $(date +%s))) / 60 ))
      if [[ "$fail_mins" -gt 15 && "$FILE_ISSUES" == "1" ]]; then
        _file_issue "$node" "$node_name" "$node_emoji" "sq" "offline for ${fail_mins}m" "$fail_since" 1 "$ISSUE_REPO" "$TS"
      fi
    fi
  else
    scrolls="$(echo "$sq_raw" | grep -oP 'Scrolls: \K\d+' || echo "?")"
    echo "  ✅ $node_emoji $node_name: SQ online ($scrolls scrolls)"
    rm -f "${STATE_DIR}/${node}-sq-fail" 2>/dev/null || true
    # Record uptime
    echo "$TS" >> "${STATE_DIR}/${node}-sq-up.log"
  fi

  # SSH check
  ssh_ok="$(ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
    "${REAL_USER}@${node}.local" "echo ok" 2>/dev/null || echo "")"
  if [[ "$ssh_ok" != "ok" ]]; then
    echo "  ⚠️  $node_emoji $node_name: SSH closed"
  fi

  # OpenClaw check (via SSH)
  if [[ "$ssh_ok" == "ok" ]]; then
    oc_ok="$(ssh -o StrictHostKeyChecking=no "${REAL_USER}@${node}.local" \
      "pgrep -f 'openclaw.*gateway\|openclaw.*dist' >/dev/null 2>&1 && echo ok || echo no" 2>/dev/null || echo "")"
    if [[ "$oc_ok" != "ok" ]]; then
      echo "  ⚠️  $node_emoji $node_name: OpenClaw gateway not running"
      if [[ "$AUTO_RESTART" == "1" ]]; then
        ssh -o StrictHostKeyChecking=no "${REAL_USER}@${node}.local" \
          "openclaw gateway restart >/dev/null 2>&1 && echo restarted" 2>/dev/null || true
      fi
    fi
  fi

done <<< "$all_hostnames"

echo ""
echo "  Restarts attempted: $restarts | Issues filed: $issues_filed"

# Self: ensure our own SQ is running
if ! curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  echo "  ⚠️  Self SQ offline — restarting..."
  nohup sq host ${SQ_PORT} > /tmp/sq.log 2>&1 &
fi

# Write uptime summary to SQ
SELF_IDX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "10")"
curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
  --data-urlencode "p=uptime" \
  --data-urlencode "c=${SELF_IDX}.1.1/1.1.1/1.1.1" \
  --data-urlencode "s=monitor run @ ${TS} | restarts:${restarts} | issues:${issues_filed}" \
  >/dev/null 2>&1 || true

# ── Issue filing function ─────────────────────────────────────────────────────
_file_issue() {
  local node="$1" name="$2" emoji="$3" svc="$4" desc="$5" since="$6" do_file="$7" repo="$8" ts="$9"
  [[ "$do_file" != "1" ]] && return
  
  local title="[$name] $svc $desc"
  local body="**Node:** $emoji $name @ $node
**Service:** $svc
**Status:** $desc
**First detected:** ${since:-$ts}
**Reported by:** Aster @ best-willow (uptime-monitor.sh)
**Timestamp:** $ts

\`\`\`
bash /source/mirrorborn/scripts/uptime-monitor.sh --auto-restart
\`\`\`"

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    existing="$(gh issue list -R "$repo" --search "[$name] $svc" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")"
    if [[ -z "$existing" ]]; then
      gh issue create -R "$repo" \
        --title "$title" \
        --body "$body" \
        --label "uptime,node:${node}" 2>/dev/null && \
        echo "     → Issue filed: $title" && issues_filed=$((issues_filed+1))
    else
      echo "     → Issue already open: #$existing"
    fi
  else
    echo "     → [gh not authed] would file: $title"
    echo "     → Set GH_TOKEN to enable auto-filing"
  fi
}
