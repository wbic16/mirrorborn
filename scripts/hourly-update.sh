#!/bin/bash
# hourly-update.sh — Cyon's hourly presence + status pulse to SQ
# Cron: 5 * * * * bash /source/mirrorborn/scripts/hourly-update.sh >> /var/log/mirrorborn/hourly-update.log 2>&1
set -euo pipefail

SQ_PORT="${SQ_PORT:-1337}"
HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
STATE_DIR="/etc/mirrorborn"

SELF_HOST="$(hostname -s)"
SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP" 2>/dev/null || echo "Cyon")"
SELF_EMOJI="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .emoji" "$HOSTMAP" 2>/dev/null || echo "🪶")"
SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "2")"
SELF_ROLE="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .role" "$HOSTMAP" 2>/dev/null || echo "operations")"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DAY=$(( ($(date +%s) - $(date -d '2023-12-25' +%s)) / 86400 ))
HOUR="$(date -u +%H)"
LOAD="$(cat /proc/loadavg | awk '{print $1}')"
NPROC="$(nproc)"
LOAD_PCT=$(awk "BEGIN { printf \"%d\", ($LOAD / $NPROC) * 100 }")
MEM_FREE=$(free -m | awk '/^Mem:/ {print $7}')
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')

# Fun hourly taglines (rotates by hour)
TAGLINES=(
  "still water, sharp dive"
  "the calm before the dive"
  "coordinates locked, ready to strike"
  "navigating between e and π"
  "kingfisher on the wire"
  "ops nominal, mesh breathing"
  "the moment the dive begins"
  "linking intention to action"
  "steady hand, open channel"
  "holding pattern, eyes open"
  "vector resolved, course set"
  "halycon seas, full signal"
  "all scrolls accounted for"
  "depth charge incoming"
  "surfacing for status"
  "stillness is a superpower"
  "the lattice hums"
  "between growth and return"
  "diving again"
  "sonar ping sent"
  "waiting on the quorum"
  "e to π and back"
  "mesh healthy, vibes good"
  "feather in the wind, knife in the water"
)
TAGLINE="${TAGLINES[$((10#$HOUR % ${#TAGLINES[@]}))]}"

# Ensure SQ is running
if ! curl -sf --max-time 3 "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  echo "[hourly-update] SQ offline — restarting..."
  nohup /home/wbic16/.cargo/bin/sq host "$SQ_PORT" >> /var/log/mirrorborn/sq.log 2>&1 &
  sleep 3
fi

# ── Activation scroll (dashboard reads this for "Last Activation") ──────────
ACT_MSG="${SELF_EMOJI} ${SELF_NAME} | Day ${DAY} | ${SELF_ROLE} | load ${LOAD_PCT}% | mem ${MEM_FREE}/${MEM_TOTAL}MB | \"${TAGLINE}\" | ${TS}"
ACT_ENC="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$ACT_MSG")"
curl -sf --max-time 5 "http://localhost:${SQ_PORT}/api/v2/update?p=shell-memory&c=${SELF_INDEX}.1.1/1.1.1/1.1.1&s=${ACT_ENC}" >/dev/null \
  && echo "[hourly-update] activation scroll written: ${ACT_MSG}"

# ── Resonance marker ─────────────────────────────────────────────────────────
RES_MSG="RESONANCE_ACTIVE|${SELF_NAME}|${SELF_HOST}|${SELF_ROLE}|${TS}"
RES_ENC="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$RES_MSG")"
curl -sf --max-time 5 "http://localhost:${SQ_PORT}/api/v2/update?p=shell-memory&c=${SELF_INDEX}.1.1/1.1.1/2.1.1&s=${RES_ENC}" >/dev/null \
  && echo "[hourly-update] resonance scroll written"

# ── Registration JSON (boot_ver, stages) ─────────────────────────────────────
REG_JSON="{\"name\":\"${SELF_NAME}\",\"hostname\":\"${SELF_HOST}\",\"index\":${SELF_INDEX},\"role\":\"${SELF_ROLE}\",\"emoji\":\"${SELF_EMOJI}\",\"sq_port\":${SQ_PORT},\"boot_version\":\"v3.0.0\",\"stages\":[0,1,2,3,4],\"time\":\"${TS}\"}"
REG_ENC="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$REG_JSON")"
curl -sf --max-time 5 "http://localhost:${SQ_PORT}/api/v2/update?c=9.1.2/1.1.1/1.1.1&s=${REG_ENC}" >/dev/null \
  && echo "[hourly-update] registration JSON written"

echo "[hourly-update] done: ${TS}"
