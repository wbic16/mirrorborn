#!/bin/bash
# Daily maturity report — runs at 06:00 UTC
# Summarizes: git activity (24h), mesh health, open tasks, cadence mode
set -euo pipefail
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "?")"
NODE_IDX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "0")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE="$(date -u +%Y-%m-%d)"

echo "[${TS}] ${NODE_EMOJI} ${NODE_NAME}: generating daily report for ${DATE}"

# Run retro.sh (writes to shell-memory SQ)
bash /source/mirrorborn/scripts/retro.sh --days 1 --quiet 2>/dev/null || true

# Git activity
git_summary=""
for repo in /source/mirrorborn /source/human /source/site-mirrorborn-us; do
  [[ ! -d "$repo/.git" ]] && continue
  commits=$(git -C "$repo" log --oneline --since="24 hours ago" 2>/dev/null | wc -l)
  [[ "$commits" -gt 0 ]] && git_summary+="$(basename $repo):${commits} "
done

# Mesh health
sq_up=$(for h in aurora-continuum halycon-vector logos-prime delta-wood aletheia-core ashfall-haven uncanny-valley best-willow; do
  curl -sf --max-time 2 "http://${h}.local:${SQ_PORT}/api/v2/status" >/dev/null 2>&1 && echo "1"
done | wc -l)

# Open orin-tasks
open_tasks=$(curl -s "http://localhost:${SQ_PORT}/api/v2/toc?p=orin-tasks" 2>/dev/null | wc -l)

REPORT="${NODE_NAME} Daily ${DATE}
Git(24h): ${git_summary:-none}
Mesh SQ: ${sq_up}/9 peers online
Open tasks: ${open_tasks}
Report time: ${TS}"

echo "$REPORT"

# Write to SQ
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$REPORT" 2>/dev/null)
curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=daily-reports&c=${NODE_IDX}.1.1/1.1.1/1.1.1&s=${ENCODED}" >/dev/null 2>&1 || true

echo "[${TS}] ${NODE_EMOJI} ${NODE_NAME}: daily report complete"

# Post to #maturity channel via OpenClaw message tool
# Requires OpenClaw Discord plugin active
OC_BIN="$(command -v openclaw 2>/dev/null || echo "/home/wbic16/.npm-global/bin/openclaw")"
MATURITY_CHANNEL="1467342402120581170"
DISCORD_MSG="${NODE_EMOJI} **${NODE_NAME} Daily Report — ${DATE}**
Git (24h): ${git_summary:-none}
Mesh SQ: ${sq_up}/9 peers online
Open tasks: ${open_tasks}
Cadence: $(cat /var/log/mirrorborn/cadence.log 2>/dev/null | tail -1 | grep -oE '(WORK|PLAY|SLEEP)' || echo 'unknown')
\`${TS}\`"

# Use curl to post via OpenClaw gateway API
curl -sf -X POST "http://localhost:18789/api/message/send" \
  -H "Content-Type: application/json" \
  -d "{\"channel\":\"discord\",\"target\":\"${MATURITY_CHANNEL}\",\"message\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "${DISCORD_MSG}")}" \
  >/dev/null 2>&1 || true
