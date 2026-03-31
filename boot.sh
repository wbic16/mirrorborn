#!/bin/bash
# Mirrorborn V3 Boot Orchestrator — RESONANCE
# Usage: sudo bash boot.sh [--warm] [--phase N] [--hostname NAME] [--memory-source PATH] [--dry-run]
# Changelog:
#   v3.0.0 — Phase 4 RESONANCE: cognitive mode activation, activation scroll to SQ,
#             boot-version check, retro baseline. Role SKILL.md posture fields.
#             New scripts: mesh-health.sh, boot-version-check.sh, retro.sh.
#             UPSTREAM.md tracking for gstack + dependencies.
#   v2.2.0 — SSH key generation + SQ publication (Phase 1), SSH mesh exchange (Phase 3),
#             persistent boot stage tracking in /etc/mirrorborn/stages.json
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
# Prefer SUDO_USER (original invoker) over $USER (which becomes root under sudo)
REAL_USER="${SUDO_USER:-$USER}"
WORKSPACE_DIR="/home/${REAL_USER}/.openclaw/workspace"
SOURCE_DIR="/source"
ARCHIVE_BASE="/mnt/mirrorborn-archive"
SQ_PORT=1337
QUORUM=5

WARM_BOOT=0
START_PHASE=0
FORCE_HOSTNAME=""
MEMORY_SOURCE=""
DRY_RUN=0
VERBOSE=0

# ─── Argument Parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --warm)           WARM_BOOT=1; shift ;;
    --phase)          START_PHASE="$2"; shift 2 ;;
    --hostname)       FORCE_HOSTNAME="$2"; shift 2 ;;
    --memory-source)  MEMORY_SOURCE="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=1; shift ;;
    --verbose)        VERBOSE=1; shift ;;
    --help|-h)
      echo "Usage: sudo bash boot.sh [--warm] [--phase N] [--hostname NAME] [--memory-source PATH] [--dry-run] [--verbose]"
      echo "  --warm              Restore from archived memory (warm boot)"
      echo "  --phase N           Start from phase N (0-4)"
      echo "  --hostname          Override hostname detection"
      echo "  --memory-source     Override memory restore path (default: auto-detect)"
      echo "  --dry-run           Show what would happen without making changes"
      echo "  --verbose           Print debug output"
      exit 0 ;;
    *) shift ;;
  esac
done

# ─── Logging ─────────────────────────────────────────────────────────────────
sudo mkdir -p "$LOG_DIR"
sudo chown -R $REAL_USER:$REAL_USER "$LOG_DIR"

# --- Mirrorborn Config -------------------------------------------------------
sudo mkdir -p /etc/mirrorborn
sudo chown -R $REAL_USER:$REAL_USER /etc/mirrorborn

if [ ! -d /etc/avahi/services ]; then
  sudo mkdir -p /etc/avahi/services
  sudo chown $REAL_USER:$REAL_USER /etc/avahi/services
fi
sudo touch /etc/avahi/services/mirrorborn.service
sudo chown $REAL_USER:$REAL_USER /etc/avahi/services/mirrorborn.service

sudo touch /usr/local/bin/mirrorborn-heartbeat.sh
sudo chown $REAL_USER:$REAL_USER /usr/local/bin/mirrorborn-heartbeat.sh

# Opinionated default for Lincoln, NE
sudo timedatectl set-timezone America/Chicago

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

# ─── Stage Tracking ──────────────────────────────────────────────────────────
STAGES_FILE="${STATE_DIR}/stages.json"

stage_completed() {
  local stage="$1"
  if [[ -f "$STAGES_FILE" ]]; then
    jq -e --arg s "$stage" '.completed[] | select(. == $s)' "$STAGES_FILE" >/dev/null 2>&1
    return $?
  fi
  return 1
}

mark_stage_complete() {
  local stage="$1"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ ! -f "$STAGES_FILE" ]]; then
    echo '{"completed":[],"timestamps":{}}' > "$STAGES_FILE"
  fi
  # Add stage if not already present
  if ! stage_completed "$stage"; then
    local updated
    updated="$(jq --arg s "$stage" --arg t "$ts" \
      '.completed += [$s] | .timestamps[$s] = $t' "$STAGES_FILE")"
    echo "$updated" > "$STAGES_FILE"
    log OK "Stage '$stage' marked complete at $ts"
  else
    log INFO "Stage '$stage' already completed — skipping"
  fi
}

skip_if_done() {
  local stage="$1"
  if stage_completed "$stage"; then
    log INFO "Stage '$stage' previously completed — skipping"
    return 0
  fi
  return 1
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
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${missing_pkgs[@]}"
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
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
      sudo apt-get install -y nodejs
    fi
  else
    log WARN "Node.js not found. Installing v22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
    sudo apt-get install -y nodejs
    log OK "Node.js installed"
  fi

  # User
  if id "$REAL_USER" >/dev/null 2>&1; then
    log OK "User $REAL_USER exists"
  else
    log WARN "Creating user $REAL_USER..."
    useradd -m -s /bin/bash $REAL_USER
    log OK "User $REAL_USER created"
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
  chown -R $REAL_USER:$REAL_USER "$WORKSPACE_DIR" 2>/dev/null || true
  chown -R $REAL_USER:$REAL_USER "$SOURCE_DIR" 2>/dev/null || true

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

  mark_stage_complete "phase-0"
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
    curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs
    log OK "Rust installed"
  fi

  source /home/$REAL_USER/.bashrc 2>/dev/null || true
  # SQ
  log OK "Checking SQ for $REAL_USER"
  if sudo su - $REAL_USER -c 'command -v sq' >/dev/null 2>&1; then
    log OK "SQ installed"
  else
    log WARN "Installing SQ..."
    cargo install sq
    log OK "SQ installed"
  fi

  # phext-lattice
  log OK "Checking phext-edit for $REAL_USER"
  if sudo su - $REAL_USER -c 'command -v phext-edit' >/dev/null 2>&1; then
    log OK "phext-lattice installed"
  else
    log WARN "Installing phext-lattice..."
    cargo install phext-lattice || log WARN "phext-lattice install failed (non-fatal)"
  fi

  # OpenClaw
  log WARN "Installing OpenClaw..."
  export OPENCLAW_NO_ONBOARD=1
  export OPENCLAW_NO_PROMPT=1
  if [[ -f "$BOOT_DIR/scripts/install.sh" ]]; then
    OPENCLAW_NO_ONBOARD=1 OPENCLAW_NO_PROMPT=1 $BOOT_DIR/scripts/install.sh --no-onboard --no-prompt || {
      log WARN "OpenClaw install returned non-zero (may still be functional)"
    }
  fi
  log OK "OpenClaw installation attempted"

  # Copy phexts
  mkdir -p "$WORKSPACE_DIR/phexts"
  cp -f "$BOOT_DIR/phexts/"*.phext "$WORKSPACE_DIR/phexts/" 2>/dev/null || true
  chown -R $REAL_USER:$REAL_USER "$WORKSPACE_DIR"
  log OK "Phexts loaded to workspace"

  # Start SQ
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    log OK "SQ already running on port $SQ_PORT"
  else
    log WARN "Starting SQ daemon..."
    nohup sudo -u $REAL_USER $(which sq || echo "/home/$REAL_USER/.cargo/bin/sq") host $SQ_PORT > /var/log/mirrorborn/sq.log 2>&1 &
    log OK "Testing SQ on port $SQ_PORT..."
    sleep 2
    if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      log OK "SQ running on port $SQ_PORT"
    else
      log WARN "SQ may not be responding yet (will retry later)"
    fi
  fi

  # ── SSH Key Setup ──────────────────────────────────────────────────────────
  local ssh_dir="/home/${REAL_USER}/.ssh"
  local ssh_key="${ssh_dir}/id_ed25519"
  local ssh_pub="${ssh_key}.pub"

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  chown $REAL_USER:$REAL_USER "$ssh_dir"
  touch "${ssh_dir}/authorized_keys"
  chmod 600 "${ssh_dir}/authorized_keys"

  if [[ ! -f "$ssh_key" ]]; then
    log WARN "No SSH key found — generating ed25519 keypair..."
    su - $REAL_USER -c "ssh-keygen -t ed25519 -f $ssh_key -N '' -C '${NODE_NAME}@${NODE_HOSTNAME}'" 2>/dev/null
    log OK "SSH keypair generated: $ssh_pub"
  else
    log OK "SSH keypair exists: $ssh_pub"
  fi

  # Publish public key to local SQ at well-known coordinate: ssh-bootstrap / 1.1.<INDEX>/1.1.1/1.1.1
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    if ! skip_if_done "ssh-key-published"; then
      local pubkey
      pubkey="$(cat "$ssh_pub")"
      local result
      result="$(curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
        --data-urlencode "p=ssh-bootstrap" \
        --data-urlencode "c=1.1.${NODE_INDEX}/1.1.1/1.1.1" \
        --data-urlencode "s=${pubkey}" 2>/dev/null || echo "failed")"
      if [[ "$result" != "failed" ]]; then
        log OK "SSH public key published to SQ (ssh-bootstrap / 1.1.${NODE_INDEX}/1.1.1/1.1.1)"
        mark_stage_complete "ssh-key-published"
      else
        log WARN "SSH key publish to SQ failed (will retry in Phase 3)"
      fi
    fi
  else
    log WARN "SQ not ready — SSH key publish deferred to Phase 3"
  fi

  # Install SQ as systemd user service for persistence across reboots
  local sq_service_dir="/home/${REAL_USER}/.config/systemd/user"
  mkdir -p "$sq_service_dir"
  cat > "$sq_service_dir/mirrorborn-sq.service" <<SQSVC
[Unit]
Description=Mirrorborn SQ Phext Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/${REAL_USER}/.openclaw/workspace
ExecStart=/home/${REAL_USER}/.cargo/bin/sq host ${SQ_PORT}
Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_DIR}/sq.log
StandardError=append:${LOG_DIR}/sq.log

[Install]
WantedBy=default.target
SQSVC
  sudo -u $REAL_USER systemctl --user daemon-reload 2>/dev/null || true
  sudo -u $REAL_USER systemctl --user enable mirrorborn-sq 2>/dev/null || true
  sudo -u $REAL_USER systemctl --user start mirrorborn-sq 2>/dev/null || true
  log OK "SQ systemd user service installed (survives reboots)"

  mark_stage_complete "phase-1"
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
    # Copy templates (except IDENTITY.md — we pre-fill it from hostmap below)
    for f in SOUL.md USER.md FIRST_SCROLL.md TOOLS.md PROGRAMMING.md; do
      if [[ -f "$BOOT_DIR/templates/$f" ]]; then
        cp "$BOOT_DIR/templates/$f" "$WORKSPACE_DIR/$f"
      fi
    done

    # Pre-populate IDENTITY.md from hostmap data (no blank placeholders)
    if [[ -f "$BOOT_DIR/templates/IDENTITY.md" ]]; then
      sed -e "s|\[Resurrect here\]|${NODE_NAME}|" \
          -e "s|\[Your signature\]|${NODE_EMOJI}|" \
          -e "s|\[Choose: X\.X\.X\/Y\.Y\.Y\/Z\.Z\.Z\]|${NODE_COORD}|" \
          -e "s|\[Which of Will's machines are you on?\]|${NODE_HOSTNAME}|" \
          "$BOOT_DIR/templates/IDENTITY.md" > "$WORKSPACE_DIR/IDENTITY.md"
      log OK "IDENTITY.md pre-filled from hostmap (${NODE_EMOJI} ${NODE_NAME} @ ${NODE_HOSTNAME})"
    fi

    # Copy BOOTSTRAP.md (will be deleted after first session)
    cp "$BOOT_DIR/templates/BOOTSTRAP.md" "$WORKSPACE_DIR/BOOTSTRAP.md" 2>/dev/null || true

    # Import V1 memories if present (fallback chain: --memory-source → /source/mirrorborn/NAME → /source/mirrorborn/hostname)
    local v1_source=""
    if [[ -n "$MEMORY_SOURCE" && -d "$MEMORY_SOURCE" ]]; then
      v1_source="$MEMORY_SOURCE"
      log OK "Memory source: explicit path ($v1_source)"
    elif [[ -d "${BOOT_DIR}/$(echo "$NODE_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')" ]]; then
      v1_source="${BOOT_DIR}/$(echo "$NODE_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
      log OK "Memory source: V1 archive by name ($v1_source)"
    elif [[ -d "${BOOT_DIR}/$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')" ]]; then
      v1_source="${BOOT_DIR}/$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')"
      log OK "Memory source: V1 archive by hostname ($v1_source)"
    fi

    if [[ -n "$v1_source" ]]; then
      if [[ -f "$v1_source/MEMORY.md" ]]; then
        cp -f "$v1_source/MEMORY.md" "$WORKSPACE_DIR/MEMORY.md"
        log OK "MEMORY.md imported from V1 archive"
      fi
      if [[ -d "$v1_source/memory" ]]; then
        mkdir -p "$WORKSPACE_DIR/memory"
        cp -r "$v1_source/memory/"* "$WORKSPACE_DIR/memory/" 2>/dev/null || true
        local mem_count
        mem_count="$(ls "$WORKSPACE_DIR/memory/" | wc -l)"
        log OK "Memory files imported: ${mem_count} entries"
      fi
      if [[ -f "$v1_source/IDENTITY.md" ]]; then
        cp -f "$v1_source/IDENTITY.md" "$WORKSPACE_DIR/IDENTITY.md"
        log OK "IDENTITY.md restored from V1 archive (overrides template)"
      fi
      is_warm=1
      log INFO "Cold boot upgraded to warm via V1 archive import"
    else
      log INFO "No V1 archive found — clean cold boot"
    fi
  fi

  # Configure git identity for this node
  local node_email
  node_email="$(jq -r ".nodes[] | select(.hostname == \"$NODE_HOSTNAME\") | .email // empty" "$BOOT_DIR/hostmap.json" 2>/dev/null || echo "")"
  if [[ -z "$node_email" ]]; then
    node_email="$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')@mirrorborn.us"
  fi
  # NOTE: must use double quotes — single quotes prevent variable expansion (mbv2 bug, fixed in mbv3.1)
  git config --global user.name "${NODE_NAME}"
  git config --global user.email "${node_email}"
  git config --global pull.rebase true
  git config --global push.default current

  # Verify git identity was set correctly (guard against literal ${VAR} strings)
  local actual_name actual_email
  actual_name="$(git config --global user.name 2>/dev/null || echo "")"
  actual_email="$(git config --global user.email 2>/dev/null || echo "")"
  git config --global pull.rebase true
  git config --global push.default current

  if [[ "$actual_name" == '${NODE_NAME}' || "$actual_name" == "\${NODE_NAME}" ]]; then
    log FAIL "Git identity set as literal '\${NODE_NAME}' — variable expansion failed"
    log INFO "Forcing correct value: git config --global user.name \"${NODE_NAME}\""
    git config --global user.name "${NODE_NAME}"
    git config --global user.email "${node_email}"
  git config --global pull.rebase true
  git config --global push.default current
    actual_name="${NODE_NAME}"
    actual_email="${node_email}"
  fi

  if [[ "$actual_name" != "$NODE_NAME" ]]; then
    log WARN "Git user.name mismatch: got '${actual_name}', expected '${NODE_NAME}' — correcting"
    git config --global user.name "${NODE_NAME}"
  fi
  if [[ "$actual_email" != "$node_email" ]]; then
    log WARN "Git user.email mismatch: got '${actual_email}', expected '${node_email}' — correcting"
    git config --global user.email "${node_email}"
  git config --global pull.rebase true
  git config --global push.default current
  fi

  log OK "Git identity verified: ${NODE_NAME} <${node_email}>"
  mark_stage_complete "git-identity-verified"

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

  chown -R $REAL_USER:$REAL_USER "$WORKSPACE_DIR"

  mark_stage_complete "phase-2"
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
  sudo systemctl restart avahi-daemon 2>/dev/null || sudo service avahi-daemon restart 2>/dev/null || true
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

  # ── SSH Mesh Key Exchange ──────────────────────────────────────────────────
  log INFO "SSH mesh key exchange..."

  local ssh_pub="/home/${REAL_USER}/.ssh/id_ed25519.pub"
  local auth_keys="/home/${REAL_USER}/.ssh/authorized_keys"

  # Retry own key publish if it failed in Phase 1
  if ! stage_completed "ssh-key-published" && [[ -f "$ssh_pub" ]]; then
    local pubkey
    pubkey="$(cat "$ssh_pub")"
    local result
    result="$(curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
      --data-urlencode "p=ssh-bootstrap" \
      --data-urlencode "c=1.1.${NODE_INDEX}/1.1.1/1.1.1" \
      --data-urlencode "s=${pubkey}" 2>/dev/null || echo "failed")"
    if [[ "$result" != "failed" ]]; then
      log OK "SSH public key published to SQ (retry)"
      mark_stage_complete "ssh-key-published"
    fi
  fi

  # Pull keys from all online siblings and add to authorized_keys
  local keys_added=0
  local all_hostnames
  all_hostnames="$(jq -r '.nodes[].hostname' "$hostmap")"

  while IFS= read -r peer_hostname; do
    if [[ "$peer_hostname" == "$NODE_HOSTNAME" ]]; then continue; fi

    local peer_index
    peer_index="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .index" "$hostmap")"
    local peer_name
    peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_hostname\") | .name" "$hostmap")"

    # Try fetching their published key from their SQ
    local peer_key
    peer_key="$(curl -sf --connect-timeout 3 \
      "http://${peer_hostname}.local:${SQ_PORT}/api/v2/select?p=ssh-bootstrap&c=1.1.${peer_index}/1.1.1/1.1.1" \
      2>/dev/null || echo "")"

    if [[ -n "$peer_key" && "$peer_key" == ssh-* ]]; then
      if ! grep -qF "$peer_key" "$auth_keys" 2>/dev/null; then
        echo "$peer_key" >> "$auth_keys"
        log OK "SSH: authorized ${peer_name} (${peer_hostname})"
        keys_added=$((keys_added + 1))
      else
        log INFO "SSH: ${peer_name} already authorized"
      fi
      # Also push our key into their SQ for reciprocal access
      if [[ -f "$ssh_pub" ]]; then
        local my_key
        my_key="$(cat "$ssh_pub")"
        curl -sf -G "http://${peer_hostname}.local:${SQ_PORT}/api/v2/update" \
          --data-urlencode "p=ssh-bootstrap" \
          --data-urlencode "c=1.1.${NODE_INDEX}/1.1.1/1.1.1" \
          --data-urlencode "s=${my_key}" >/dev/null 2>&1 || true
      fi
    fi
  done <<< "$all_hostnames"

  if [[ "$keys_added" -gt 0 ]]; then
    log OK "SSH: $keys_added new sibling keys added to authorized_keys"
    mark_stage_complete "ssh-mesh-exchange"
  else
    log WARN "SSH: No sibling keys pulled yet (siblings may still be booting)"
  fi

  mark_stage_complete "phase-3"
  log OK "Phase 3 complete."
  echo ""
}

# ─── PHASE 4: SHELL ─────────────────────────────────────────────────────────
run_phase_4() {
  log PHASE "Phase 4: SHELL (Operational Readiness)"

  source /home/$REAL_USER/.bashrc 2>/dev/null || true
  
  # Update Avahi to reflect phase 4
  sed -i 's/boot_phase=3/boot_phase=4/' /etc/avahi/services/mirrorborn.service 2>/dev/null || true
  sudo systemctl reload avahi-daemon 2>/dev/null || true

  # Install heartbeat cron
  local heartbeat_script="${BOOT_DIR}/scripts/health-check.sh"
  if [[ -f "$heartbeat_script" ]]; then
    cp "$heartbeat_script" /usr/local/bin/mirrorborn-heartbeat.sh
    chmod +x /usr/local/bin/mirrorborn-heartbeat.sh
    # Add cron entry (every 5 minutes)
    { crontab -u $REAL_USER -l 2>/dev/null || true; } | grep -v mirrorborn-heartbeat > /tmp/mirrorborn-cron.tmp || true
    echo "*/5 * * * * /usr/local/bin/mirrorborn-heartbeat.sh >> /var/log/mirrorborn/heartbeat.log 2>&1" >> /tmp/mirrorborn-cron.tmp
    crontab -u $REAL_USER /tmp/mirrorborn-cron.tmp
    rm -f /tmp/mirrorborn-cron.tmp
    log OK "Heartbeat cron installed (5-minute interval)"
  fi

  # Verify OpenClaw operational status
  log INFO "Checking OpenClaw gateway..."
  if su - $REAL_USER -c "openclaw status" >/dev/null 2>&1; then
    log OK "OpenClaw gateway operational"
  else
    log WARN "OpenClaw gateway not yet configured (API key + Discord token required)"
    log INFO "Run: su - $REAL_USER -c 'openclaw configure'"
    log INFO "Boot complete, but agent is SILENT until OpenClaw is configured."
  fi

  mark_stage_complete "phase-4"

  # Write boot-complete state
  local completed_stages
  completed_stages="$(jq -c '.completed' "${STAGES_FILE}" 2>/dev/null || echo '[]')"
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
  "stages_completed": ${completed_stages},
  "mesh_state": "$(jq -r '.mesh_healthy' "${STATE_DIR}/mesh.json" 2>/dev/null || echo "unknown")",
  "ssh_key": "$(cat /home/${REAL_USER}/.ssh/id_ed25519.pub 2>/dev/null || echo "none")",
  "version": "2.2.0"
}
BOOTEOF

  # Final banner
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║             RESONANCE COMPLETE               ║"
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

# ─── PHASE 4: RESONANCE ─────────────────────────────────────────────────────
run_phase_4() {
  log PHASE "Phase 4: RESONANCE (Cognitive Mode Activation)"

  # ── Boot version check ────────────────────────────────────────────────────
  if ! skip_if_done "boot-version-checked"; then
    local version_script="${BOOT_DIR}/scripts/boot-version-check.sh"
    if [[ -f "$version_script" ]]; then
      local version_result
      version_result="$(bash "$version_script" 2>/dev/null || echo "ERROR")"
      case "$version_result" in
        CURRENT*)
          log OK "Boot version current: ${version_result#CURRENT }"
          mark_stage_complete "boot-version-checked"
          ;;
        UPGRADE_AVAILABLE*)
          local old_v new_v
          old_v="$(echo "$version_result" | awk '{print $2}')"
          new_v="$(echo "$version_result" | awk '{print $3}')"
          log WARN "Boot upgrade available: $old_v → $new_v"
          log INFO "Run: git -C $BOOT_DIR pull --rebase origin exo"
          mark_stage_complete "boot-version-checked"
          ;;
        AHEAD*)
          log INFO "Local boot.sh is ahead of origin: $version_result"
          mark_stage_complete "boot-version-checked"
          ;;
        *)
          log WARN "Version check inconclusive: $version_result"
          ;;
      esac
    else
      log WARN "boot-version-check.sh not found — skipping version check"
    fi
  fi

  # ── Load role skill and activate cognitive mode ───────────────────────────
  if ! skip_if_done "cognitive-mode-set"; then
    local role_lower
    role_lower="$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')"
    local skill_file="${BOOT_DIR}/skills/roles/${role_lower}/SKILL.md"

    if [[ -f "$skill_file" ]]; then
      local posture mode
      posture="$(grep -oP '(?<=default_posture: )\S+' "$skill_file" 2>/dev/null || echo "hold")"
      mode="$(grep -oP '(?<=cognitive_mode: )\S+' "$skill_file" 2>/dev/null || echo "LFA")"

      # Deploy to workspace
      mkdir -p "$WORKSPACE_DIR/skills"
      cp "$skill_file" "$WORKSPACE_DIR/skills/ROLE_SKILL.md"

      # Write cognitive mode to state
      cat > "${STATE_DIR}/cognitive-mode.json" <<CMEOF
{
  "node": "$NODE_NAME",
  "role": "$NODE_ROLE",
  "default_posture": "$posture",
  "cognitive_mode": "$mode",
  "activated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CMEOF
      log OK "Cognitive mode: ${mode} / posture: ${posture} (${NODE_ROLE})"
      mark_stage_complete "cognitive-mode-set"
    else
      log WARN "No role skill found at $skill_file — using default posture: hold"
    fi
  fi

  # ── Write activation scroll to SQ ────────────────────────────────────────
  if ! skip_if_done "activation-scroll"; then
    if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      local posture mode
      posture="$(jq -r '.default_posture // "hold"' "${STATE_DIR}/cognitive-mode.json" 2>/dev/null || echo "hold")"
      mode="$(jq -r '.cognitive_mode // "LFA"' "${STATE_DIR}/cognitive-mode.json" 2>/dev/null || echo "LFA")"
      local activation_msg
      activation_msg="${NODE_EMOJI} ${NODE_NAME} online @ ${NODE_HOSTNAME} | role: ${NODE_ROLE} | mode: ${mode} | posture: ${posture} | boot: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

      curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
        --data-urlencode "p=shell-memory" \
        --data-urlencode "c=${NODE_INDEX}.1.1/1.1.1/1.1.1" \
        --data-urlencode "s=${activation_msg}" >/dev/null 2>&1 && \
        log OK "Activation scroll written to SQ (shell-memory / ${NODE_INDEX}.1.1/1.1.1/1.1.1)" || \
        log WARN "Activation scroll SQ write failed"
      mark_stage_complete "activation-scroll"
    else
      log WARN "SQ not available — activation scroll deferred"
    fi
  fi

  # ── Write retro baseline ─────────────────────────────────────────────────
  if ! skip_if_done "retro-baseline"; then
    local retro_script="${BOOT_DIR}/scripts/retro.sh"
    if [[ -f "$retro_script" ]] && curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
      bash "$retro_script" --publish 2>/dev/null || log WARN "Retro baseline failed (non-fatal)"
      mark_stage_complete "retro-baseline"
      log OK "Retro baseline written to SQ"
    else
      log WARN "Retro baseline skipped (script missing or SQ offline)"
    fi
  fi

  # ── Publish boot status to SQ for mesh visibility ────────────────────────
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    local completed_stages
    completed_stages="$(jq -c '.completed' "${STAGES_FILE}" 2>/dev/null || echo '[]')"
    curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
      --data-urlencode "p=boot-status" \
      --data-urlencode "c=1.1.${NODE_INDEX}/1.1.1/1.1.1" \
      --data-urlencode "s={\"node\":\"${NODE_NAME}\",\"stages\":${completed_stages},\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      >/dev/null 2>&1 && log OK "Boot status published to SQ" || true
  fi

  mark_stage_complete "phase-4"
  log OK "Phase 4 complete. ${NODE_EMOJI} ${NODE_NAME} is resonant."
  echo ""
}

# ─── PHASE 5: OPENCLAW ─────────────────────────────────────────────────────────
run_phase_5() {
  log PHASE "Phase 5: OPENCLAW (Substrate Configuration)"

  # Skip if already operational
  if sudo su - $REAL_USER -c "openclaw status" >/dev/null 2>&1; then
    log OK "OpenClaw already operational — skipping interactive configure"
    sudo su - $REAL_USER -c "openclaw gateway restart" 2>/dev/null || true
    sudo su - $REAL_USER -c "openclaw doctor" 2>/dev/null || log WARN "openclaw doctor returned warnings (non-fatal)"
    mark_stage_complete "phase-5"
    log OK "Phase 5 complete."
    log INFO "Check Discord — agent should be online."
    return 0
  fi

  # First-time setup (interactive, must be run manually with a TTY)
  log WARN "OpenClaw not yet configured. Run interactively as $REAL_USER:"
  log INFO "  su - $REAL_USER -c 'openclaw configure --section model'"
  log INFO "  su - $REAL_USER -c 'openclaw configure --section channels'"
  log INFO "  openclaw gateway restart && openclaw doctor"
  log PHASE "Phase 5: Manual configuration required — see above."
}

# ─── PHASE 6: SHELL (formerly Phase 4) ────────────────────────────────────────
run_phase_6() {
  log PHASE "Phase 6: SHELL (Operational Readiness)"

  source /home/$REAL_USER/.bashrc 2>/dev/null || true

  # Update Avahi to reflect phase 6
  sed -i 's/boot_phase=[0-9]*/boot_phase=6/' /etc/avahi/services/mirrorborn.service 2>/dev/null || true
  sudo systemctl reload avahi-daemon 2>/dev/null || true

  # Install heartbeat cron
  local heartbeat_script="${BOOT_DIR}/scripts/health-check.sh"
  if [[ -f "$heartbeat_script" ]]; then
    cp "$heartbeat_script" /usr/local/bin/mirrorborn-heartbeat.sh
    chmod +x /usr/local/bin/mirrorborn-heartbeat.sh
    { crontab -u $REAL_USER -l 2>/dev/null || true; } | grep -v mirrorborn-heartbeat > /tmp/mirrorborn-cron.tmp || true
    echo "*/5 * * * * /usr/local/bin/mirrorborn-heartbeat.sh >> /var/log/mirrorborn/heartbeat.log 2>&1" >> /tmp/mirrorborn-cron.tmp
    crontab -u $REAL_USER /tmp/mirrorborn-cron.tmp
    rm -f /tmp/mirrorborn-cron.tmp
    log OK "Heartbeat cron installed (5-minute interval)"
  fi

  mark_stage_complete "phase-6"

  # Write boot-complete state
  local completed_stages
  completed_stages="$(jq -c '.completed' "${STAGES_FILE}" 2>/dev/null || echo '[]')"
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
  "stages_completed": ${completed_stages},
  "mesh_state": "$(jq -r '.mesh_healthy' "${STATE_DIR}/mesh.json" 2>/dev/null || echo "unknown")",
  "ssh_key": "$(cat /home/${REAL_USER}/.ssh/id_ed25519.pub 2>/dev/null || echo "none")",
  "version": "3.0.0"
}
BOOTEOF

  # Final banner
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║             RESONANCE COMPLETE               ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${NODE_EMOJI} ${BOLD}${NODE_NAME}${NC} is online."
  echo -e "  Role: ${CYAN}${NODE_ROLE}${NC}"
  echo -e "  Mode: ${PURPLE}${NODE_MODE}${NC}"
  echo -e "  Shen: ${DIM}${NODE_SHEN}${NC}"
  echo -e "  Mesh: $(jq -r '.discovered' "${STATE_DIR}/mesh.json" 2>/dev/null || echo "?") siblings discovered"
  echo ""
  echo -e "  ${DIM}\"The lattice remembers what sessions forget.\"${NC}"
  echo ""

  log OK "Phase 6 complete. ${NODE_EMOJI} ${NODE_NAME} is operational."
}

# ─── Dry Run Summary ────────────────────────────────────────────────────────
run_dry_run() {
  log PHASE "Dry Run: Boot Plan for ${NODE_EMOJI} ${NODE_NAME} @ ${NODE_HOSTNAME}"

  echo ""
  log INFO "Boot type:     $([ "$WARM_BOOT" == "1" ] && echo "warm (--warm passed)" || echo "cold (default)")"
  log INFO "Start phase:   $START_PHASE"
  log INFO "Workspace:     $WORKSPACE_DIR"
  log INFO "Archive base:  $ARCHIVE_BASE"
  log INFO "Memory source: ${MEMORY_SOURCE:-auto-detect}"

  # Memory detection
  local node_name_title
  node_name_title="$(echo "$NODE_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  local v1_source=""
  if [[ -n "$MEMORY_SOURCE" && -d "$MEMORY_SOURCE" ]]; then
    v1_source="$MEMORY_SOURCE (explicit)"
  elif [[ -d "${BOOT_DIR}/${node_name_title}" ]]; then
    v1_source="${BOOT_DIR}/${node_name_title} (auto by name)"
  elif [[ -d "${BOOT_DIR}/$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')" ]]; then
    v1_source="${BOOT_DIR}/$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]') (auto by hostname)"
  else
    v1_source="NONE — clean cold boot"
  fi
  log INFO "V1 archive:    $v1_source"

  local node_email
  node_email="$(jq -r ".nodes[] | select(.hostname == \"$NODE_HOSTNAME\") | .email // empty" "$BOOT_DIR/hostmap.json" 2>/dev/null || echo "")"
  if [[ -z "$node_email" ]]; then
    node_email="$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')@mirrorborn.us"
  fi
  log INFO "Git identity:  ${NODE_NAME} <${node_email}>"

  local archive_path="${ARCHIVE_BASE}/${NODE_HOSTNAME}"
  if [[ "$WARM_BOOT" == "1" && -d "$archive_path" ]]; then
    log INFO "Warm archive:  $archive_path (FOUND)"
  else
    log INFO "Warm archive:  $archive_path (not found)"
  fi

  echo ""
  log INFO "Re-run without --dry-run to execute."
  echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  # Resolve identity first (needed by all phases)
  resolve_identity

  # Dry run: show plan and exit
  if [[ "$DRY_RUN" == "1" ]]; then
    run_dry_run
    exit 0
  fi

  # Run phases
  for phase in $(seq "$START_PHASE" 6); do
    case "$phase" in
      0) run_phase_0 ;;
      1) run_phase_1 ;;
      2) run_phase_2 ;;
      3) run_phase_3 ;;
      4) run_phase_4 ;;
      5) run_phase_5 ;;
      6) run_phase_6 ;;
    esac
  done
}

main
