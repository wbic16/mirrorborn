#!/bin/bash
# Mirrorborn Shell Dashboard
# Displays SSH, SQ, key exchange, and boot version status across all nodes
# Usage: bash dashboard.sh [--json] [--html /path/to/output.html] [--publish]
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
OUTPUT_JSON=0
OUTPUT_HTML=""
PUBLISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)   OUTPUT_JSON=1; shift ;;
    --html)   OUTPUT_HTML="$2"; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    *) shift ;;
  esac
done

export PATH="$HOME/.cargo/bin:$PATH"

SELF_HOST="$(hostname -s)"
SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP")"
SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP")"
SELF_EMOJI="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .emoji" "$HOSTMAP" 2>/dev/null || echo "?")"
SELF_ROLE="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .role" "$HOSTMAP" 2>/dev/null || echo "?")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BOOT_VERSION="$(grep -oP '(?<=version: )\d+\.\d+\.\d+' /source/mirrorborn/boot.sh 2>/dev/null | head -1 || echo "unknown")"

declare -a NODE_DATA
sq_online=0; ssh_online=0; keys_published=0; total=0

# Skip nodes marked offline in hostmap; include all others
all_hostnames="$(jq -r '.nodes[] | select((.status // "online") != "offline") | .hostname' "$HOSTMAP")"

while IFS= read -r node; do
  [[ "$node" == "$SELF_HOST" ]] && continue
  total=$((total+1))
  idx="$(jq -r ".nodes[] | select(.hostname==\"$node\") | .index" "$HOSTMAP")"
  name="$(jq -r ".nodes[] | select(.hostname==\"$node\") | .name" "$HOSTMAP")"
  emoji="$(jq -r ".nodes[] | select(.hostname==\"$node\") | .emoji" "$HOSTMAP")"
  role="$(jq -r ".nodes[] | select(.hostname==\"$node\") | .role" "$HOSTMAP")"
  posture="$(jq -r ".nodes[] | select(.hostname==\"$node\") | .primary_mode // \"LFA\"" "$HOSTMAP")"

  # SQ
  sq_raw="$(curl -sf --connect-timeout 2 "http://${node}.local:${SQ_PORT}/api/v2/status" 2>/dev/null || echo "")"
  if [[ -n "$sq_raw" ]]; then
    scrolls="$(echo "$sq_raw" | grep -oP 'Scrolls: \K\d+' 2>/dev/null || echo "?")"
    sq_st="online"; sq_detail="${scrolls}s"; sq_online=$((sq_online+1))
  else
    sq_st="offline"; sq_detail="-"
  fi

  # SSH
  ssh_ok="$(ssh -n -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
    "${REAL_USER}@${node}.local" "echo ok" 2>/dev/null || echo "")"
  if [[ "$ssh_ok" == "ok" ]]; then
    ssh_st="open"; ssh_online=$((ssh_online+1))
  else
    ssh_st="closed"
  fi

  # SSH key published
  key="$(curl -sf --connect-timeout 2 \
    "http://${node}.local:${SQ_PORT}/api/v2/select?p=ssh-bootstrap&c=1.1.${idx}/1.1.1/1.1.1" \
    2>/dev/null || echo "")"
  if [[ "$key" == ssh-* ]]; then
    key_st="published"; keys_published=$((keys_published+1))
    key_short="$(echo "$key" | awk '{print $2}' | cut -c1-16)..."
  else
    key_st="none"; key_short="-"
  fi

  # Boot version / stages
  boot_raw="$(curl -sf --connect-timeout 2 \
    "http://${node}.local:${SQ_PORT}/api/v2/select?p=boot-status&c=1.1.${idx}/1.1.1/1.1.1" \
    2>/dev/null || echo "")"
  if [[ -n "$boot_raw" ]]; then
    node_ver="$(echo "$boot_raw" | grep -oP '(?<="version":")[^"]+' || echo "?")"
    [[ -z "$node_ver" ]] && node_ver="reported"
  else
    node_ver="unreported"
  fi

  # Activation scroll
  act="$(curl -sf --connect-timeout 2 \
    "http://${node}.local:${SQ_PORT}/api/v2/select?p=shell-memory&c=${idx}.1.1/1.1.1/1.1.1" \
    2>/dev/null | cut -c1-60 || echo "")"
  [[ -z "$act" ]] && act="-"

  NODE_DATA+=("${idx}|${name}|${emoji}|${role}|${node}|${sq_st}|${sq_detail}|${ssh_st}|${key_st}|${key_short}|${node_ver}|${act}")
done <<< "$all_hostnames"

# Self node
self_sq_raw="$(curl -sf "http://localhost:${SQ_PORT}/api/v2/status" 2>/dev/null || echo "")"
[[ -n "$self_sq_raw" ]] && self_sq="online($(echo "$self_sq_raw" | grep -oP 'Scrolls: \K\d+' 2>/dev/null || echo "?")s)" || self_sq="offline"
self_stages="$(jq -r '.completed | length' /etc/mirrorborn/stages.json 2>/dev/null || echo "0")"

# ── Terminal output ───────────────────────────────────────────────────────────
if [[ "$OUTPUT_JSON" == "0" && -z "$OUTPUT_HTML" ]]; then
  echo ""
  printf "\033[1;35m  ╔══════════════════════════════════════════════════════════════════╗\033[0m\n"
  printf "\033[1;35m  ║          MIRRORBORN SHELL DASHBOARD — %s          ║\033[0m\n" "$(date -u '+%H:%M UTC')"
  printf "\033[1;35m  ╚══════════════════════════════════════════════════════════════════╝\033[0m\n"
  echo ""
  printf "\033[2m  💡 %-12s  boot.sh: %-8s  SQ: %-18s  stages: %s\033[0m\n" \
    "Aster(self)" "$BOOT_VERSION" "$self_sq" "$self_stages"
  echo ""
  printf "  \033[36m%-3s %-6s %-12s %-10s %-12s %-8s %-6s %-14s\033[0m\n" \
    "IDX" "EMOJI" "NAME" "ROLE" "SQ" "SSH" "KEY" "VERSION"
  printf "  %s\n" "──────────────────────────────────────────────────────────────────"

  for entry in "${NODE_DATA[@]}"; do
    IFS='|' read -r idx name emoji role node sq_st sq_detail ssh_st key_st key_short node_ver act <<< "$entry"

    sq_color="\033[31m"; [[ "$sq_st" == "online" ]] && sq_color="\033[32m"
    ssh_color="\033[31m"; [[ "$ssh_st" == "open" ]] && ssh_color="\033[32m"
    key_color="\033[33m"; [[ "$key_st" == "published" ]] && key_color="\033[32m"
    ver_color="\033[33m"; [[ "$node_ver" != "unreported" ]] && ver_color="\033[32m"

    printf "  %s%-3s %-2s    %-12s %-10s ${sq_color}%-12s\033[0m ${ssh_color}%-6s\033[0m ${key_color}%-6s\033[0m ${ver_color}%-14s\033[0m\n" \
      "" "$idx" "$emoji" "$name" "$role" "${sq_st}(${sq_detail})" "$ssh_st" "$key_st" "$node_ver"
  done

  echo ""
  printf "  \033[2mSummary: SQ %d/%d · SSH %d/%d · Keys %d/%d · boot.sh %s\033[0m\n" \
    "$sq_online" "$total" "$ssh_online" "$total" "$keys_published" "$total" "$BOOT_VERSION"
  echo ""
fi

# ── HTML output ───────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT_HTML" ]]; then
  cat > "$OUTPUT_HTML" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta http-equiv="refresh" content="30">
<title>Mirrorborn Shell Dashboard</title>
<style>
  body { background:#0a0a1a; color:#e0e0e0; font-family:'Courier New',monospace; padding:20px; }
  h1 { color:#fff; border-bottom:2px solid #9b6fff; padding-bottom:8px; font-size:1.3em; }
  .ts { color:#555; font-size:0.8em; margin-bottom:1.5em; }
  table { width:100%; border-collapse:collapse; font-size:0.85em; }
  th { color:#9b6fff; border-bottom:1px solid #333; padding:8px 10px; text-align:left; }
  td { padding:7px 10px; border-bottom:1px solid #1a1a2e; }
  tr:hover td { background:rgba(255,255,255,0.03); }
  .online { color:#4ade80; }
  .offline { color:#f87171; }
  .open { color:#4ade80; }
  .closed { color:#f87171; }
  .published { color:#4ade80; }
  .none { color:#fbbf24; }
  .reported { color:#4ade80; }
  .unreported { color:#fbbf24; }
  .self-row td { background:rgba(155,111,255,0.08); }
  .summary { margin-top:1.5em; color:#888; font-size:0.85em; }
  .summary span { color:#9b6fff; font-weight:bold; }
  .act { color:#555; font-size:0.8em; max-width:300px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }
  .pill { display:inline-block; padding:2px 8px; border-radius:10px; font-size:0.75em; }
</style>
</head>
<body>
<h1>💡 Mirrorborn Shell Dashboard</h1>
<div class="ts">Generated: ${TS} · Auto-refresh: 30s · Source: ${SELF_NAME} @ ${SELF_HOST} · boot.sh: ${BOOT_VERSION}</div>

<table>
<tr>
  <th>#</th><th>Node</th><th>Role</th><th>SQ</th><th>Scrolls</th>
  <th>SSH</th><th>SSH Key</th><th>Boot Ver</th><th>Last Activation</th>
</tr>

<tr class="self-row">
  <td>${SELF_INDEX}</td>
  <td>${SELF_EMOJI} ${SELF_NAME} (self)</td>
  <td>${SELF_ROLE}</td>
  <td class="online">online</td>
  <td>$(echo "$self_sq_raw" | grep -oP 'Scrolls: \K\d+' 2>/dev/null || echo "?")</td>
  <td class="open">self</td>
  <td class="published">self</td>
  <td class="reported">${BOOT_VERSION}</td>
  <td class="act">${self_stages} stages complete</td>
</tr>
HTMLEOF

  for entry in "${NODE_DATA[@]}"; do
    IFS='|' read -r idx name emoji role node sq_st sq_detail ssh_st key_st key_short node_ver act <<< "$entry"
    cat >> "$OUTPUT_HTML" << ROWEOF
<tr>
  <td>${idx}</td>
  <td>${emoji} ${name}</td>
  <td>${role}</td>
  <td class="${sq_st}">${sq_st}</td>
  <td>${sq_detail}</td>
  <td class="${ssh_st}">${ssh_st}</td>
  <td class="${key_st}">${key_st}</td>
  <td class="$([ "$node_ver" != "unreported" ] && echo reported || echo unreported)">${node_ver}</td>
  <td class="act">${act}</td>
</tr>
ROWEOF
  done

  cat >> "$OUTPUT_HTML" << FOOTEREOF
</table>

<div class="summary">
  SQ online: <span>${sq_online}/${total}</span> ·
  SSH open: <span>${ssh_online}/${total}</span> ·
  Keys published: <span>${keys_published}/${total}</span> ·
  boot.sh: <span>${BOOT_VERSION}</span>
</div>
</body>
</html>
FOOTEREOF
  echo "Dashboard written to: $OUTPUT_HTML"
fi

# ── Publish to SQ ─────────────────────────────────────────────────────────────
if [[ "$PUBLISH" == "1" ]] && curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  summary="dashboard@${TS} | SQ:${sq_online}/${total} | SSH:${ssh_online}/${total} | keys:${keys_published}/${total} | ver:${BOOT_VERSION}"
  curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
    --data-urlencode "p=mesh-dashboard" \
    --data-urlencode "c=1.1.${SELF_INDEX}/1.1.1/1.1.1" \
    --data-urlencode "s=${summary}" >/dev/null 2>&1
fi
