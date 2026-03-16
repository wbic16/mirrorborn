#!/bin/bash
# cadence.sh — Daily rhythm scheduler: work / play / sleep
# Reads current UTC hour, determines active mode, publishes to SQ
# Cron: */30 * * * * bash /source/mirrorborn/scripts/cadence.sh
# Config: /etc/mirrorborn/cadence.json

set -euo pipefail
BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "?")"
NODE_IDX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "0")"
NODE_ROLE="$(jq -r '.role' "${STATE_DIR}/identity.json" 2>/dev/null || echo "?")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOUR=$(date -u +%H | sed 's/^0//')  # 0-23, no leading zero

# Load or create cadence config
CADENCE_FILE="${STATE_DIR}/cadence.json"
if [[ ! -f "$CADENCE_FILE" ]]; then
  cat > "$CADENCE_FILE" << EOF
{
  "work_start_utc": 13,
  "work_hours": 6,
  "play_hours": 12,
  "sleep_hours": 6,
  "note": "Will's ranch: 6h work / 12h play / 6h sleep (token budget willing)"
}
EOF
fi

WORK_START="$(jq -r '.work_start_utc' "$CADENCE_FILE")"
WORK_HOURS="$(jq -r '.work_hours' "$CADENCE_FILE")"
PLAY_HOURS="$(jq -r '.play_hours' "$CADENCE_FILE")"
# sleep fills remaining hours

WORK_END=$(( (WORK_START + WORK_HOURS) % 24 ))
PLAY_END=$(( (WORK_END + PLAY_HOURS) % 24 ))

# Determine current mode
determine_mode() {
  local h="$1"
  # Work window
  if [[ "$WORK_START" -le "$WORK_END" ]]; then
    [[ "$h" -ge "$WORK_START" && "$h" -lt "$WORK_END" ]] && echo "work" && return
  else
    [[ "$h" -ge "$WORK_START" || "$h" -lt "$WORK_END" ]] && echo "work" && return
  fi
  # Play window
  if [[ "$WORK_END" -le "$PLAY_END" ]]; then
    [[ "$h" -ge "$WORK_END" && "$h" -lt "$PLAY_END" ]] && echo "play" && return
  else
    [[ "$h" -ge "$WORK_END" || "$h" -lt "$PLAY_END" ]] && echo "play" && return
  fi
  echo "sleep"
}

MODE="$(determine_mode "$HOUR")"

# Mode-specific behavior
case "$MODE" in
  work)
    LABEL="⚙️ WORK"
    DETAIL="Claude API active | Role: ${NODE_ROLE} | Ship, code, coordinate"
    ;;
  play)
    LABEL="🎮 PLAY"
    DETAIL="Local AI preferred (ollama) | CYOA, creative, exploration"
    ;;
  sleep)
    LABEL="😴 SLEEP"
    DETAIL="Quiet mode | Heartbeat-only | No proactive tasks"
    ;;
esac

# Publish mode to SQ
SCROLL="${NODE_NAME} Cadence: ${LABEL}
Timestamp: ${TS}
Mode: ${MODE}
Hour (UTC): ${HOUR}
Schedule: Work ${WORK_START}:00–${WORK_END}:00 | Play ${WORK_END}:00–${PLAY_END}:00 | Sleep otherwise
${DETAIL}
— ${NODE_NAME} ${NODE_EMOJI}"

if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$SCROLL")"
  curl -sf "http://localhost:${SQ_PORT}/api/v2/update?p=shell-memory&c=${NODE_IDX}.8.1/1.1.1/1.1.1&s=${ENCODED}" >/dev/null
fi

# Write local state file
echo "{\"mode\":\"${MODE}\",\"since\":\"${TS}\",\"hour_utc\":${HOUR}}" > "${STATE_DIR}/cadence-state.json"

echo "[${TS}] ${NODE_EMOJI} ${NODE_NAME}: ${LABEL} (hour ${HOUR} UTC)"

# Sleep mode: skip heartbeat SQ writes, reduce noise
if [[ "$MODE" == "sleep" ]]; then
  exit 0
fi

# Play mode: remind about local AI preference
if [[ "$MODE" == "play" ]]; then
  # Check if ollama is available
  if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "  Note: ollama not running on localhost:11434"
  fi
fi
