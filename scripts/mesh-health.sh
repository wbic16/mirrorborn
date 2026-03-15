#!/bin/bash
# Mirrorborn Mesh Health Dashboard
# Single command for full mesh status: SQ, SSH, stage completion, key exchange
# Usage: bash mesh-health.sh [--json] [--publish]
# --json    Output JSON to stdout
# --publish Write results to local SQ at mesh-health/1.1.<INDEX>/1.1.1/1.1.1
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
OUTPUT_JSON=0
PUBLISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)    OUTPUT_JSON=1; shift ;;
    --publish) PUBLISH=1; shift ;;
    *) shift ;;
  esac
done

SELF_HOST="$(hostname -s)"

if [[ ! -f "$HOSTMAP" ]]; then
  echo "Error: hostmap.json not found at $HOSTMAP" >&2
  exit 1
fi

SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP")"
SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP")"

[[ "$OUTPUT_JSON" == "0" ]] && {
  echo ""
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║       MIRRORBORN MESH HEALTH DASHBOARD       ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo "  Self: ${SELF_NAME} @ ${SELF_HOST}"
  echo "  Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
}

# ── Per-node checks ──────────────────────────────────────────────────────────
nodes_json="["
first=1
sq_up=0
ssh_up=0
keys_exchanged=0
total=0

all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"

while IFS= read -r peer_host; do
  if [[ "$peer_host" == "$SELF_HOST" ]]; then continue; fi

  peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .name" "$HOSTMAP")"
  peer_emoji="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .emoji" "$HOSTMAP")"
  peer_index="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .index" "$HOSTMAP")"
  peer_role="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .role" "$HOSTMAP")"
  total=$((total + 1))

  # SQ check
  sq_status="down"
  sq_result="$(curl -sf --connect-timeout 2 "http://${peer_host}.local:${SQ_PORT}/api/v2/status" 2>/dev/null && echo "up" || echo "down")"
  if [[ "$sq_result" == "up" ]]; then
    sq_status="up"
    sq_up=$((sq_up + 1))
  fi

  # SSH check
  ssh_status="down"
  if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes \
       "${REAL_USER}@${peer_host}.local" "echo ok" >/dev/null 2>&1; then
    ssh_status="up"
    ssh_up=$((ssh_up + 1))
  fi

  # Key exchange check
  key_status="none"
  peer_key="$(curl -sf --connect-timeout 2 \
    "http://${peer_host}.local:${SQ_PORT}/api/v2/select?p=ssh-bootstrap&c=1.1.${peer_index}/1.1.1/1.1.1" \
    2>/dev/null || echo "")"
  if [[ -n "$peer_key" && "$peer_key" == ssh-* ]]; then
    key_status="published"
    keys_exchanged=$((keys_exchanged + 1))
  fi

  # Stage completion check (via SQ boot-complete if published)
  stages_status="unknown"
  boot_complete="$(curl -sf --connect-timeout 2 \
    "http://${peer_host}.local:${SQ_PORT}/api/v2/select?p=boot-status&c=1.1.${peer_index}/1.1.1/1.1.1" \
    2>/dev/null || echo "")"
  if [[ -n "$boot_complete" ]]; then
    stages_status="reported"
  fi

  sq_icon="❌"; [[ "$sq_status" == "up" ]] && sq_icon="✅"
  ssh_icon="❌"; [[ "$ssh_status" == "up" ]] && ssh_icon="✅"
  key_icon="❌"; [[ "$key_status" == "published" ]] && key_icon="🔑"

  [[ "$OUTPUT_JSON" == "0" ]] && \
    printf "  %s %-12s  SQ:%s  SSH:%s  Key:%s\n" \
      "$peer_emoji" "$peer_name" "$sq_icon" "$ssh_icon" "$key_icon"

  [[ "$first" == "0" ]] && nodes_json+=","
  nodes_json+="{\"name\":\"${peer_name}\",\"hostname\":\"${peer_host}\",\"index\":${peer_index},\"role\":\"${peer_role}\",\"sq\":\"${sq_status}\",\"ssh\":\"${ssh_status}\",\"key\":\"${key_status}\"}"
  first=0

done <<< "$all_hostnames"

nodes_json+="]"

# ── Self status ───────────────────────────────────────────────────────────────
self_sq="down"
curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1 && self_sq="up"

self_stages="$(cat /etc/mirrorborn/stages.json 2>/dev/null | jq -c '.completed' || echo '[]')"

# ── Summary ───────────────────────────────────────────────────────────────────
[[ "$OUTPUT_JSON" == "0" ]] && {
  echo ""
  echo "  ── Summary ──────────────────────────────────────"
  echo "  SQ online:      ${sq_up}/${total} siblings"
  echo "  SSH reachable:  ${ssh_up}/${total} siblings"
  echo "  Keys published: ${keys_exchanged}/${total} siblings"
  echo "  Local SQ:       ${self_sq}"
  echo "  Local stages:   ${self_stages}"
  echo ""
}

result_json="{
  \"self\": \"${SELF_NAME}\",
  \"self_host\": \"${SELF_HOST}\",
  \"self_index\": ${SELF_INDEX},
  \"self_sq\": \"${self_sq}\",
  \"self_stages\": ${self_stages},
  \"sq_up\": ${sq_up},
  \"ssh_up\": ${ssh_up},
  \"keys_exchanged\": ${keys_exchanged},
  \"total_siblings\": ${total},
  \"nodes\": ${nodes_json},
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
}"

[[ "$OUTPUT_JSON" == "1" ]] && echo "$result_json"

# ── Publish to SQ ─────────────────────────────────────────────────────────────
if [[ "$PUBLISH" == "1" ]] && [[ "$self_sq" == "up" ]]; then
  curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
    --data-urlencode "p=mesh-health" \
    --data-urlencode "c=1.1.${SELF_INDEX}/1.1.1/1.1.1" \
    --data-urlencode "s=${result_json}" >/dev/null 2>&1 && \
    echo "  Published mesh health to SQ (mesh-health / 1.1.${SELF_INDEX}/1.1.1/1.1.1)" || \
    echo "  Warning: SQ publish failed" >&2
fi
