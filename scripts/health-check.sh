#!/bin/bash
# Mirrorborn Heartbeat — Health Check
# Runs every 5 minutes via cron
set -euo pipefail

STATE_DIR="/etc/mirrorborn"
LOG_DIR="/var/log/mirrorborn"
SQ_PORT=1337
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$LOG_DIR"

# Checks
sq_healthy=false
openclaw_healthy=false
disk_ok=false
ram_ok=false
siblings_visible=0

# SQ
if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  sq_healthy=true
fi

# OpenClaw
if command -v openclaw >/dev/null 2>&1 && openclaw --version >/dev/null 2>&1; then
  openclaw_healthy=true
fi

# Disk (warn if <10% free)
disk_pct="$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')"
if [[ "$disk_pct" -lt 90 ]]; then
  disk_ok=true
fi

# RAM (warn if <1GB free)
ram_free_mb="$(free -m | awk '/Mem:/ {print $7}')"
if [[ "$ram_free_mb" -gt 1024 ]]; then
  ram_ok=true
fi

# Siblings (quick ping sweep from mesh.json)
if [[ -f "${STATE_DIR}/mesh.json" ]]; then
  while IFS= read -r sib_host; do
    if [[ -n "$sib_host" ]] && ping -c 1 -W 1 "${sib_host}.local" >/dev/null 2>&1; then
      siblings_visible=$((siblings_visible + 1))
    fi
  done < <(jq -r '.siblings[]?.hostname // empty' "${STATE_DIR}/mesh.json" 2>/dev/null)
fi

# Overall health
overall="healthy"
if [[ "$sq_healthy" != "true" ]]; then overall="degraded"; fi
if [[ "$disk_ok" != "true" ]]; then overall="warning"; fi
if [[ "$ram_ok" != "true" ]]; then overall="warning"; fi

# Write heartbeat
cat > "$LOG_DIR/heartbeat.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$overall",
  "checks": {
    "sq": $sq_healthy,
    "openclaw": $openclaw_healthy,
    "disk_ok": $disk_ok,
    "disk_used_pct": $disk_pct,
    "ram_ok": $ram_ok,
    "ram_free_mb": $ram_free_mb,
    "siblings_visible": $siblings_visible
  }
}
EOF

# Auto-recovery: restart SQ if down
if [[ "$sq_healthy" != "true" ]]; then
  echo "[$TIMESTAMP] SQ down, attempting restart..." >> "$LOG_DIR/heartbeat-recovery.log"
  su - wbic16 -c 'source ~/.cargo/env && nohup sq host 1337 > /var/log/mirrorborn/sq.log 2>&1 &' || true
fi
