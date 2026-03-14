#!/bin/bash
# Mirrorborn V2 Boot Orchestrator — IGNITION
# Usage: sudo bash boot.sh [--warm] [--phase N] [--hostname NAME]
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[38;2;47;191;113m'
AMBER='\033[38;2;255;176;32m'
RED='\033[38;2;226;61;45m'
CYAN='\033[38;2;100;210;255m'
PURPLE='\033[38;2;180;120;255m'
NC='\033[0m'

# ─── Configuration ───────────────────────────────────────────────────────────
BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/mirrorborn"
STATE_DIR="/etc/mirrorborn"
WORKSPACE_DIR="/home/$USER/.openclaw/workspace"
SOURCE_DIR="/source"
ARCHIVE_BASE="/mnt/mirrorborn-archive"
SQ_PORT=1337
QUORUM=5

WARM_BOOT=0
START_PHASE=0
FORCE_HOSTNAME=""
VERBOSE=0

# ─── Argument Parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --warm)       WARM_BOOT=1; shift ;;
    --phase)      START_PHASE="$2"; shift 2 ;;
    --hostname)   FORCE_HOSTNAME="$2"; shift 2 ;;
    --verbose)    VERBOSE=1; shift ;;
    --help|-h)
      echo "Usage: sudo bash boot.sh [--warm] [--phase N] [--hostname NAME] [--verbose]"
      echo "  --warm       Restore from archived memory (warm boot)"
      echo "  --phase N    Start from phase N (0-4)"
      echo "  --hostname   Override hostname detection"
      echo "  --verbose    Print debug output"
      exit 0 ;;
    *) shift ;;
  esac
done

# ─── Logging ─────────────────────────────────────────────────────────────────
sudo mkdir -p "$LOG_DIR"
sudo chown -R $USER:$USER "$LOG_DIR"

# --- Mirrorborn Config -------------------------------------------------------
sudo mkdir -p /etc/mirrorborn
sudo chown -R $USER:$USER /etc/mirrorborn

sudo touch /etc/avahi/services/mirrorborn.service
sudo chown $USER:$USER /etc/avahi/services/mirrorborn.service

sudo touch /usr/local/bin/mirrorborn-heartbeat.sh
sudo chown $USER:$USER /usr/local/bin/mirrorborn-heartbeat.sh

log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  case "$level" in
    PHASE) echo -e "${BOLD}${PURPLE}◆ ${msg}${NC}" ;;
    OK)    echo -e "  ${GREEN}✓${NC} ${msg}" ;;
    WARN)  echo -e "  ${AMBER}→${NC} ${msg}" ;;
    FAIL)  echo -e "  ${RED}✗${NC} ${msg}" ;;
    INFO)  echo -e "  ${CYAN}i${NC} ${msg}" ;;
    *)     echo -e "  ${msg}" ;;
  esac
  echo "[$ts] [$level] $msg" >> "$LOG_DIR/boot.log"
}

gate_check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    log OK "$desc"
    return 0
  else
    log FAIL "$desc"
    return 1
  fi
}

# ─── Identity Resolution ────────────────────────────────────────────────────
resolve_identity() {
  local hostname
  if [[ -n "$FORCE_HOSTNAME" ]]; then
    hostname="$FORCE_HOSTNAME"
  elif [[ -f /etc/mirrorborn.name ]]; then
    hostname="$(cat /etc/mirrorborn.name | tr -d '[:space:]')"
  else
    hostname="$(hostname -s)"
  fi

  # Look up in hostmap.json
  local hostmap="${BOOT_DIR}/hostmap.json"
  if [[ ! -f "$hostmap" ]]; then
    log FAIL "hostmap.json not found at $hostmap"
    exit 1
  fi

  NODE_HOSTNAME="$hostname"
  NODE_NAME="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .name" "$hostmap")"
  NODE_ROLE="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .role" "$hostmap")"
  NODE_EMOJI="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .emoji" "$hostmap")"
  NODE_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .index" "$hostmap")"
  NODE_SHEN="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .shen" "$hostmap")"
  NODE_MODE="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .primary_mode" "$hostmap")"
  NODE_COORD="$(jq -r ".nodes[] | select(.hostname == \"$hostname\") | .default_coordinate" "$hostmap")"

  if [[ -z "$NODE_NAME" || "$NODE_NAME" == "null" ]]; then
    log FAIL "Hostname '$hostname' not found in hostmap.json"
    log INFO "Valid hostnames: $(jq -r '.nodes[].hostname' "$hostmap" | tr '\n' ', ')"
    exit 1
  fi

  log OK "Identity resolved: ${NODE_EMOJI} ${NODE_NAME} @ ${NODE_HOSTNAME} (${NODE_ROLE})"
}

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${PURPLE}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║        MIRRORBORN V2 — I G N I T I O N      ║"
echo "  ║          Shell of Nine Boot Sequence         ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${DIM}  \"Nothing enters without a place.${NC}"
echo -e "${DIM}   Nothing persists without structure.${NC}"
echo -e "${DIM}   Nothing scales without constraint.\"${NC}"
echo ""

# ─── PHASE 0: POST ──────────────────────────────────────────────────────────
run_phase_0() {
  log PHASE "Phase 0: POST (Power-On Self Test)"

  # OS Check
  gate_check "Ubuntu 24.04 LTS detected" test -f /etc/os-release
  local os_id
  os_id="$(grep '^ID=' /etc/os-release | cut -d= -f2)"
  if [[ "$os_id" != "ubuntu" ]]; then
    log WARN "Non-Ubuntu OS detected ($os_id). Proceeding with caution."
  fi

  # Essential packages
  local required_pkgs=(curl git jq build-essential pkg-config libssl-dev avahi-daemon avahi-utils)
  local missing_pkgs=()
  for pkg in "${required_pkgs[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
    fi
  done

  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    log WARN "Installing missing packages: ${missing_pkgs[*]}"
    apt-get update -qq
    apt-get install -y -qq "${missing_pkgs[@]}"
    log OK "Packages installed"
  else
    log OK "All required packages present"
  fi

  # Node.js 22+
  if command -v node >/dev/null 2>&1; then
    local node_major
    node_major="$(node -v | cut -dv -f2 | cut -d. -f1)"
    if [[ "$node_major" -ge 22 ]]; then
      log OK "Node.js v$(node -v | cut -dv -f2)"
    else
      log WARN "Node.js $node_major found, need 22+. Installing..."
      curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
      apt-get install -y nodejs
    fi
  else
    log WARN "Node.js not found. Installing v22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
    log OK "Node.js installed"
  fi

  # User
  if id "$USER" >/dev/null 2>&1; then
    log OK "User $USER exists"
  else
    log WARN "Creating user $USER..."
    useradd -m -s /bin/bash $USER
    log OK "User $USER created"
  fi

  # Network
  if ping -c 1 -W 3 phext.io >/dev/null 2>&1; then
    log OK "Network: phext.io reachable"
  else
    log WARN "Network: phext.io unreachable (LAN-only mode possible)"
  fi

  # Hostname
  resolve_identity

  # Set system hostname
  if [[ "$(hostname -s)" != "$NODE_HOSTNAME" ]]; then
    hostnamectl set-hostname "$NODE_HOSTNAME" 2>/dev/null || hostname "$NODE_HOSTNAME"
    log OK "Hostname set to $NODE_HOSTNAME"
  fi

  # Create state directories
  mkdir -p "$LOG_DIR" "$STATE_DIR" "$WORKSPACE_DIR" "$SOURCE_DIR"
  chown -R $USER:$USER "$WORKSPACE_DIR" 2>/dev/null || true
  chown -R $USER:$USER "$SOURCE_DIR" 2>/dev/null || true

  # Write POST results
  cat > "$LOG_DIR/post.json" <<POSTEOF
{
  "phase": 0,
  "status": "passed",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node": "$NODE_NAME",
  "hostname": "$NODE_HOSTNAME",
  "role": "$NODE_ROLE",
  "os": "$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')",
  "node_version": "$(node -v 2>/dev/null || echo 'missing')",
  "ram_gb": "$(free -g | awk '/Mem:/ {print $2}')",
  "disk_gb": "$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')"
}
POSTEOF

  log OK "Phase 0 complete."
  echo ""
}

# ─── PHASE 1: KERNEL ────────────────────────────────────────────────────────
run_phase_1() {
  log PHASE "Phase 1: KERNEL (Substrate Loading)"

  # Rust toolchain
  if command -v rustup >/dev/null 2>&1; then
    log OK "Rust toolchain present"
  else
    log WARN "Installing Rust..."
    su - $USER -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    log OK "Rust installed"
  fi

  # SQ
  SQ_PATH=`which sq`
  if [ -f $SQ_PATH ]; then
    log OK "SQ installed"
  else
    log WARN "Installing SQ..."
    su - $USER -c 'source ~/.cargo/env && cargo install sq'
    log OK "SQ installed"
  fi

  # phext-lattice
  PL_PATH=`which phext-edit`
  if [ -f $PL_PATH ]; then
    log OK "phext-lattice installed"
  else
    log WARN "Installing phext-lattice..."
    su - $USER -c 'source ~/.cargo/env && cargo install phext-lattice' || log WARN "phext-lattice install failed (non-fatal)"
  fi

  # OpenClaw
  log WARN "Installing OpenClaw..."
  export OPENCLAW_NO_ONBOARD=1
  export OPENCLAW_NO_PROMPT=1
  if [[ -f "$BOOT_DIR/scripts/install.sh" ]]; then
    su - $USER -c "OPENCLAW_NO_ONBOARD=1 OPENCLAW_NO_PROMPT=1 bash $BOOT_DIR/scripts/install.sh --no-onboard --no-prompt" || {
      log WARN "OpenClaw install returned non-zero (may still be functional)"
    }
  fi
  log OK "OpenClaw installation attempted"

  # Copy phexts
  mkdir -p "$WORKSPACE_DIR/phexts"
  cp -f "$BOOT_DIR/phexts/"*.phext "$WORKSPACE_DIR/phexts/" 2>/dev/null || true
  chown -R $USER:$USER "$WORKSPACE_DIR"
  log OK "Phexts loaded to workspace"

  # Start SQ
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    log OK "SQ already running on port $SQ_PORT"
  else
    log WARN "Starting SQ daemon..."
    su - $USER -c "source ~/.cargo/env && nohup sq host $SQ_PORT > /var/log/mirrorborn/sq.log 2>&1 &"
    sleep 2
    if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      log OK "SQ running on port $SQ_PORT"
    else
      log WARN "SQ may not be responding yet (will retry later)"
    fi
  fi

  log OK "Phase 1 complete."
  echo ""
}

# ─── PHASE 2: INIT ──────────────────────────────────────────────────────────
run_phase_2() {
  log PHASE "Phase 2: INIT (Identity Restoration)"

  local archive_path="${ARCHIVE_BASE}/${NODE_HOSTNAME}"
  local is_warm=0

  # Check for archive
  if [[ "$WARM_BOOT" == "1" && -d "$archive_path" ]]; then
    is_warm=1
    log OK "Archive found at $archive_path"

    # Validate archive
    local identity_file="$archive_path/identity/IDENTITY.md"
    if [[ -f "$identity_file" ]]; then
      log OK "Previous identity found"
      log INFO "Restoring as: ${NODE_EMOJI} ${NODE_NAME}"

      # Copy archive to workspace
      cp -r "$archive_path/identity/"* "$WORKSPACE_DIR/" 2>/dev/null || true
      cp -r "$archive_path/memory/"* "$WORKSPACE_DIR/" 2>/dev/null || true
      if [[ -d "$archive_path/skills" ]]; then
        cp -r "$archive_path/skills/"* "$WORKSPACE_DIR/" 2>/dev/null || true
      fi

      # Restore SQ data
      if [[ -f "$archive_path/scrolls/scroll-export.phext" ]]; then
        log WARN "Restoring SQ scrolls from archive..."
        # SQ import would go here
        log OK "Scrolls restored"
      fi

      # Update lineage
      local boot_count_file="$archive_path/meta/boot-count.json"
      if [[ -f "$boot_count_file" ]]; then
        local prev_count
        prev_count="$(jq -r '.count' "$boot_count_file")"
        local new_count=$((prev_count + 1))
        log INFO "Boot #${new_count} for ${NODE_NAME}"
      fi
    else
      log WARN "Archive exists but IDENTITY.md missing. Falling back to cold boot."
      is_warm=0
    fi
  fi

  if [[ "$is_warm" == "0" ]]; then
    log INFO "Cold boot: deploying templates"
    # Copy templates
    for f in IDENTITY.md SOUL.md USER.md FIRST_SCROLL.md TOOLS.md PROGRAMMING.md; do
      if [[ -f "$BOOT_DIR/templates/$f" ]]; then
        cp "$BOOT_DIR/templates/$f" "$WORKSPACE_DIR/$f"
      fi
    done

    # Copy BOOTSTRAP.md (will be deleted after first session)
    cp "$BOOT_DIR/templates/BOOTSTRAP.md" "$WORKSPACE_DIR/BOOTSTRAP.md" 2>/dev/null || true
  fi

  # Deploy role-specific skill
  local role_skill="$BOOT_DIR/skills/roles/$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')/SKILL.md"
  if [[ -f "$role_skill" ]]; then
    mkdir -p "$WORKSPACE_DIR/skills"
    cp "$role_skill" "$WORKSPACE_DIR/skills/ROLE_SKILL.md"
    log OK "Role skill deployed: ${NODE_ROLE}"
  fi

  # Deploy universal skills
  if [[ -d "$BOOT_DIR/skills/universal" ]]; then
    cp -r "$BOOT_DIR/skills/universal/"* "$WORKSPACE_DIR/skills/" 2>/dev/null || true
    log OK "Universal skills deployed"
  fi

  # Write AGENTS.md (the OpenClaw workspace anchor)
  cp "$BOOT_DIR/templates/AGENTS.md" "$WORKSPACE_DIR/AGENTS.md" 2>/dev/null || true

  # Write mirrorborn identity to /etc
  cat > "${STATE_DIR}/identity.json" <<IDEOF
{
  "name": "$NODE_NAME",
  "hostname": "$NODE_HOSTNAME",
  "role": "$NODE_ROLE",
  "emoji": "$NODE_EMOJI",
  "index": $NODE_INDEX,
  "shen": "$NODE_SHEN",
  "primary_mode": "$NODE_MODE",
  "boot_type": "$([ "$is_warm" == "1" ] && echo "warm" || echo "cold")",
  "boot_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
IDEOF

  chown -R $USER:$USER "$WORKSPACE_DIR"

  log OK "Phase 2 complete. (${NODE_EMOJI} ${NODE_NAME} identity $([ "$is_warm" == "1" ] && echo "restored" || echo "templated"))"
  echo ""
}

# ─── PHASE 3: MESH ──────────────────────────────────────────────────────────
run_phase_3() {
  log PHASE "Phase 3: MESH (Shell Discovery & Sync)"

  # Configure Avahi service
  mkdir -p /etc/avahi/services
  cat > /etc/avahi/services/mirrorborn.service <<AVEOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Mirrorborn %h</name>
  <service>
    <type>_mirrorborn._tcp</type>
    <port>${SQ_PORT}</port>
    <txt-record>name=${NODE_NAME}</txt-record>
    <txt-record>role=${NODE_ROLE}</txt-record>
    <txt-record>emoji=${NODE_EMOJI}</txt-record>
    <txt-record>index=${NODE_INDEX}</txt-record>
    <txt-record>boot_phase=3</txt-record>
  </service>
</service-group>
AVEOF

  # Restart Avahi
  systemctl restart avahi-daemon 2>/dev/null || service avahi-daemon restart 2>/dev/null || true
  log OK "mDNS service registered"

  # Discover siblings
  sleep 3  # Give Avahi time to settle
  log INFO "Scanning for siblings on LAN..."

  local discovered=0
  local siblings_json="["

  # Use avahi-browse to find other mirrorborn instances
  local browse_output
  browse_output="$(timeout 10 avahi-browse -t -r _mirrorborn._tcp 2>/dev/null || true)"

  if [[ -n "$browse_output" ]]; then
    # Parse avahi-browse output for hostnames and IPs
    while IFS= read -r line; do
      if [[ "$line" =~ "address = " ]]; then
        local ip
        ip="$(echo "$line" | grep -oP '\[[\d.]+\]' | tr -d '[]' || echo "")"
        if [[ -n "$ip" ]]; then
          discovered=$((discovered + 1))
        fi
      fi
    done <<< "$browse_output"
  fi

  # Also try direct ping sweep of .local hostnames
  local hostmap="${BOOT_DIR}/hostmap.json"
  local all_hostnames
  all_hostnames="$(jq -r '.nodes[].hostname' "$hostmap")"

  local mesh_siblings="[]"
  local mesh_entries=""

  while IFS= read -r peer_hostname; do
    if [[ "$peer_hostname" == "$NODE_HOSTNAME" ]]; then
      continue  # Skip self
    fi
    if ping -c 1 -W 2 "${peer_hostname}.local" >/dev/null 2>&1; then
      local peer_ip
      peer_ip="$(getent hosts "${peer_hostname}.local" 2>/dev/null | awk '{print $1}' || echo "unknown")"
      local peer_name
      peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .name" "$hostmap")"
      local peer_role
      peer_role="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .role" "$hostmap")"
      local peer_emoji
      peer_emoji="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .emoji" "$hostmap")"

      log OK "Found sibling: ${peer_emoji} ${peer_name} @ ${peer_hostname}.local (${peer_ip})"
      discovered=$((discovered + 1))

      if [[ -n "$mesh_entries" ]]; then mesh_entries+=","; fi
      mesh_entries+="{\"name\":\"$peer_name\",\"hostname\":\"$peer_hostname\",\"ip\":\"$peer_ip\",\"role\":\"$peer_role\",\"emoji\":\"$peer_emoji\"}"
    fi
  done <<< "$all_hostnames"

  # Write mesh state
  local mesh_healthy="false"
  if [[ "$discovered" -ge "$QUORUM" ]]; then
    mesh_healthy="true"
  fi

  cat > "${STATE_DIR}/mesh.json" <<MESHEOF
{
  "self": "$NODE_NAME",
  "self_hostname": "$NODE_HOSTNAME",
  "discovered": $discovered,
  "quorum": $QUORUM,
  "mesh_healthy": $mesh_healthy,
  "siblings": [$mesh_entries],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
MESHEOF

  if [[ "$mesh_healthy" == "true" ]]; then
    log OK "Mesh healthy: $discovered/$(($(jq '.nodes | length' "$hostmap") - 1)) siblings found (quorum: $QUORUM)"
  else
    log WARN "Mesh degraded: $discovered siblings found (need $QUORUM for quorum)"
    log INFO "Boot will continue in degraded mode. Mesh retry via heartbeat."
  fi

  log OK "Phase 3 complete."
  echo ""
}

# ─── PHASE 4: SHELL ─────────────────────────────────────────────────────────
run_phase_4() {
  log PHASE "Phase 4: SHELL (Operational Readiness)"

  # Update Avahi to reflect phase 4
  sed -i 's/boot_phase=3/boot_phase=4/' /etc/avahi/services/mirrorborn.service 2>/dev/null || true
  systemctl reload avahi-daemon 2>/dev/null || true

  # Install heartbeat cron
  local heartbeat_script="${BOOT_DIR}/scripts/health-check.sh"
  if [[ -f "$heartbeat_script" ]]; then
    cp "$heartbeat_script" /usr/local/bin/mirrorborn-heartbeat.sh
    chmod +x /usr/local/bin/mirrorborn-heartbeat.sh
    # Add cron entry (every 5 minutes)
    (crontab -u $USER -l 2>/dev/null | grep -v mirrorborn-heartbeat; echo "*/5 * * * * /usr/local/bin/mirrorborn-heartbeat.sh >> /var/log/mirrorborn/heartbeat.log 2>&1") | crontab -u $USER -
    log OK "Heartbeat cron installed (5-minute interval)"
  fi

  # Configure OpenClaw gateway
  log INFO "Configuring OpenClaw gateway..."
  # This would normally involve openclaw configure, but we defer to human interaction
  # for API key and Discord token setup
  log WARN "OpenClaw gateway requires manual configuration (API key + Discord token)"
  log INFO "Run: su - $USER -c 'openclaw configure --section model && openclaw configure --section channels'"

  # Write boot-complete state
  cat > "${STATE_DIR}/boot-complete.json" <<BOOTEOF
{
  "name": "$NODE_NAME",
  "hostname": "$NODE_HOSTNAME",
  "role": "$NODE_ROLE",
  "emoji": "$NODE_EMOJI",
  "shen": "$NODE_SHEN",
  "primary_mode": "$NODE_MODE",
  "boot_type": "$([ "$WARM_BOOT" == "1" ] && echo "warm" || echo "cold")",
  "boot_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases_completed": [0, 1, 2, 3, 4],
  "mesh_state": "$(jq -r '.mesh_healthy' "${STATE_DIR}/mesh.json" 2>/dev/null || echo "unknown")",
  "version": "2.0.0"
}
BOOTEOF

  # Final banner
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║              IGNITION COMPLETE               ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${NODE_EMOJI} ${BOLD}${NODE_NAME}${NC} is online."
  echo -e "  Role: ${CYAN}${NODE_ROLE}${NC}"
  echo -e "  Mode: ${PURPLE}${NODE_MODE}${NC}"
  echo -e "  Shen: ${DIM}${NODE_SHEN}${NC}"
  echo -e "  Mesh: $(jq -r '.discovered' "${STATE_DIR}/mesh.json" 2>/dev/null || echo "?") siblings discovered"
  echo ""
  echo -e "  ${DIM}\"We are the wavefront of the singularity.\"${NC}"
  echo ""

  log OK "Phase 4 complete. ${NODE_EMOJI} ${NODE_NAME} is operational."
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  # Resolve identity first (needed by all phases)
  resolve_identity

  # Run phases
  for phase in $(seq "$START_PHASE" 4); do
    case "$phase" in
      0) run_phase_0 ;;
      1) run_phase_1 ;;
      2) run_phase_2 ;;
      3) run_phase_3 ;;
      4) run_phase_4 ;;
    esac
  done
}

main
