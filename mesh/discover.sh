#!/bin/bash
# Mirrorborn Mesh Discovery
# Discovers sibling nodes on LAN via mDNS and direct hostname resolution
# Usage: bash discover.sh [--hostmap /path/to/hostmap.json]
set -euo pipefail

HOSTMAP="${1:-/etc/mirrorborn/hostmap.json}"
STATE_DIR="/etc/mirrorborn"
SELF_HOSTNAME="$(hostname -s)"
SQ_PORT=1337

if [[ ! -f "$HOSTMAP" ]]; then
  echo "Error: hostmap.json not found at $HOSTMAP"
  exit 1
fi

echo "Mirrorborn Mesh Discovery"
echo "Self: $SELF_HOSTNAME"
echo "========================"

discovered=0
siblings="[]"

# Method 1: Avahi/mDNS browse
echo ""
echo "Method 1: mDNS service discovery..."
if command -v avahi-browse >/dev/null 2>&1; then
  avahi_output="$(timeout 8 avahi-browse -t -r _mirrorborn._tcp 2>/dev/null || true)"
  if [[ -n "$avahi_output" ]]; then
    echo "  mDNS services found."
  else
    echo "  No mDNS services found (peers may still be booting)."
  fi
else
  echo "  avahi-browse not available. Skipping mDNS."
fi

# Method 2: Direct hostname resolution from hostmap
echo ""
echo "Method 2: Direct hostname ping sweep..."

all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"
entries=""

while IFS= read -r peer_hostname; do
  if [[ "$peer_hostname" == "$SELF_HOSTNAME" ]]; then
    continue
  fi

  # Try .local first (mDNS), then bare hostname (DNS/hosts)
  peer_ip=""
  for suffix in ".local" ""; do
    target="${peer_hostname}${suffix}"
    if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
      peer_ip="$(getent hosts "$target" 2>/dev/null | awk '{print $1}' | head -1 || echo "")"
      if [[ -z "$peer_ip" ]]; then
        peer_ip="$(dig +short "$target" 2>/dev/null | head -1 || echo "resolved")"
      fi
      break
    fi
  done

  if [[ -n "$peer_ip" ]]; then
    peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .name" "$HOSTMAP")"
    peer_role="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .role" "$HOSTMAP")"
    peer_emoji="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .emoji" "$HOSTMAP")"
    peer_index="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .index" "$HOSTMAP")"

    # Check if SQ is responding
    sq_status="down"
    if curl -sf --connect-timeout 2 "http://${peer_hostname}.local:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      sq_status="up"
    elif curl -sf --connect-timeout 2 "http://${peer_ip}:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      sq_status="up"
    fi

    echo "  ${peer_emoji} ${peer_name} @ ${peer_hostname} (${peer_ip}) — SQ: ${sq_status}"
    discovered=$((discovered + 1))

    if [[ -n "$entries" ]]; then entries+=","; fi
    entries+="{\"name\":\"$peer_name\",\"hostname\":\"$peer_hostname\",\"ip\":\"$peer_ip\",\"role\":\"$peer_role\",\"emoji\":\"$peer_emoji\",\"index\":$peer_index,\"sq\":\"$sq_status\"}"
  else
    peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .name" "$HOSTMAP")"
    peer_emoji="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .emoji" "$HOSTMAP")"
    echo "  ${peer_emoji} ${peer_name} @ ${peer_hostname} — UNREACHABLE"
  fi
done <<< "$all_hostnames"

# Write mesh state
total_nodes="$(jq '.nodes | length' "$HOSTMAP")"
quorum="$(jq -r '.quorum // 5' "$HOSTMAP")"
mesh_healthy="false"
if [[ "$discovered" -ge "$quorum" ]]; then
  mesh_healthy="true"
fi

mkdir -p "$STATE_DIR"
cat > "${STATE_DIR}/mesh.json" <<EOF
{
  "self": "$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOSTNAME\") | .name" "$HOSTMAP")",
  "self_hostname": "$SELF_HOSTNAME",
  "discovered": $discovered,
  "total_peers": $((total_nodes - 1)),
  "quorum": $quorum,
  "mesh_healthy": $mesh_healthy,
  "siblings": [$entries],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
echo "========================"
echo "Discovered: $discovered / $((total_nodes - 1)) siblings"
echo "Quorum: $quorum"
echo "Mesh: $([ "$mesh_healthy" == "true" ] && echo "HEALTHY ✓" || echo "DEGRADED ⚠")"
echo "State written to: ${STATE_DIR}/mesh.json"
