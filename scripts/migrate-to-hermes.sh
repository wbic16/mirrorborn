#!/usr/bin/env bash
# migrate-to-hermes.sh — Live OpenClaw → Hermes migration for one node
#
# Works in two modes:
#   SHELL MODE  (default) — run from an already-migrated Mirrorborn node
#               that has hermes-agent locally and shares API keys via .env
#   STANDALONE MODE (--standalone) — run locally by any OpenClaw user on
#               the Web; installs hermes-agent from PyPI/GitHub directly,
#               no source node needed, keys come entirely from OpenClaw
#
# Usage:
#   ./migrate-to-hermes.sh <hostname>                    # Shell mode
#   ./migrate-to-hermes.sh <hostname> --dry-run          # Print steps, no exec
#   ./migrate-to-hermes.sh <hostname> --force            # Re-run if Hermes active
#   ./migrate-to-hermes.sh <hostname> --user <username>  # Override remote username
#   ./migrate-to-hermes.sh <hostname> --no-mdns          # Use plain hostname (not .local)
#   ./migrate-to-hermes.sh <hostname> --standalone       # Standalone mode (no source node)
#   ./migrate-to-hermes.sh localhost --standalone        # Migrate the local machine
#
# What it does:
#   1. Install hermes-agent on target (rsync from source node, or pip install)
#   2. Create Python venv + install deps on target
#   3. Extract API keys from OpenClaw on target (extract-openclaw-keys.py)
#   4. Seed ~/.hermes/.env (from OpenClaw keys + shared keys in shell mode)
#   5. Seed ~/.hermes/config.yaml with sane defaults
#      - Fixes DISCORD_HOME_CHANNEL from DISCORD_HOME_CHANNEL_ID if needed
#   6. Migrate phext files and identity (SOUL.md etc.) from ~/.openclaw/workspace
#   7. Install + enable hermes-gateway.service (systemd user)
#   8. Stop + disable openclaw-gateway.service
#   9. Start hermes-gateway and verify
#
# Preserves: all phext files, SOUL.md, openclaw binary (not removed)
# Requires:  SSH key access to target (or localhost), Python 3.11+, rsync

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }
die()     { error "$*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
TARGET_HOST=""
DRY_RUN=0
FORCE=0
STANDALONE=0
USE_MDNS=1                        # append .local by default (shell/LAN mode)
REMOTE_USER="${USER:-$(whoami)}"  # default to current user, not hardcoded
SOURCE_NODE="elven-path"          # only used in shell mode

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=1;    shift ;;
        --force)     FORCE=1;      shift ;;
        --standalone) STANDALONE=1; shift ;;
        --no-mdns)   USE_MDNS=0;   shift ;;
        --user)      REMOTE_USER="$2"; shift 2 ;;
        --source)    SOURCE_NODE="$2"; shift 2 ;;
        -h|--help)   grep '^#' "$0" | head -35 | sed 's/^# \?//'; exit 0 ;;
        -*)          die "Unknown option: $1" ;;
        *)           TARGET_HOST="$1"; shift ;;
    esac
done

[[ -z "$TARGET_HOST" ]] && die "No target host specified. Usage: $0 <hostname> [--standalone]"

# Build the SSH target address
# localhost/127.x never gets .local suffix; others only get it in mDNS mode
_is_local=0
if [[ "$TARGET_HOST" == "localhost" || "$TARGET_HOST" =~ ^127\. || "$TARGET_HOST" =~ ^:: ]]; then
    _is_local=1
    SSH_TARGET="localhost"
elif [[ "$USE_MDNS" == "1" ]]; then
    SSH_TARGET="${TARGET_HOST}.local"
else
    SSH_TARGET="$TARGET_HOST"
fi

[[ "$_is_local" == "0" && "$STANDALONE" == "0" && "$TARGET_HOST" == "$SOURCE_NODE" ]] \
    && die "Target and source are the same node ($TARGET_HOST) — nothing to do."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract-openclaw-keys.py"
[[ -f "$EXTRACT_SCRIPT" ]] || die "Missing: $EXTRACT_SCRIPT"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

# For localhost, skip SSH and run directly
_ssh() {
    if [[ "$_is_local" == "1" ]]; then
        bash -c "$*"
    else
        ssh $SSH_OPTS "${REMOTE_USER}@${SSH_TARGET}" "$@"
    fi
}

remote() {
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    [[ "$DRY_RUN" == "1" ]] && { echo -e "  ${YELLOW}DRY:${NC} $*"; return 0; }
    if [[ "$_is_local" == "1" ]]; then
        bash -c "$*"
    else
        ssh $SSH_OPTS "${REMOTE_USER}@${SSH_TARGET}" "$@"
    fi
}

remote_script() {
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    [[ "$DRY_RUN" == "1" ]] && { echo -e "  ${YELLOW}DRY:${NC} (script block)"; cat; return 0; }
    if [[ "$_is_local" == "1" ]]; then
        bash -s "$@"
    else
        ssh $SSH_OPTS "${REMOTE_USER}@${SSH_TARGET}" bash -s "$@"
    fi
}

_scp() {
    local src="$1" dst="$2"
    if [[ "$_is_local" == "1" ]]; then
        cp "$src" "$dst"
    else
        scp $SSH_OPTS "$src" "${REMOTE_USER}@${SSH_TARGET}:${dst}" > /dev/null
    fi
}

# ── Connectivity check ────────────────────────────────────────────────────────
header "Preflight: $TARGET_HOST"

if [[ "$DRY_RUN" == "0" && "$_is_local" == "0" ]]; then
    ssh $SSH_OPTS "${REMOTE_USER}@${SSH_TARGET}" "echo connected" > /dev/null 2>&1 \
        || die "Cannot reach ${REMOTE_USER}@${SSH_TARGET} via SSH"
    success "SSH OK"
elif [[ "$_is_local" == "1" ]]; then
    success "Local machine — no SSH needed"
fi

# Check if already migrated
if [[ "$FORCE" == "0" && "$DRY_RUN" == "0" ]]; then
    if remote "check hermes-gateway status" \
        "systemctl --user is-active hermes-gateway.service" > /dev/null 2>&1; then
        success "hermes-gateway already active on $TARGET_HOST — skipping (use --force to re-run)"
        exit 0
    fi
fi

# ── Step 1: Install hermes-agent on target ────────────────────────────────────
header "Step 1: Install hermes-agent → $TARGET_HOST"

if [[ "$STANDALONE" == "1" ]]; then
    # Standalone mode: install from PyPI (or pip install from GitHub if not published)
    remote_script "Install hermes-agent via pip" << 'REMOTE'
set -euo pipefail
HERMES_DIR="$HOME/.hermes/hermes-agent"
mkdir -p "$HOME/.hermes"

# Try PyPI first, fall back to GitHub
if python3 -m pip show hermes-agent > /dev/null 2>&1; then
    echo "  hermes-agent already installed system-wide"
elif [[ -d "$HERMES_DIR" ]]; then
    echo "  hermes-agent directory already present"
else
    echo "  Cloning hermes-agent from GitHub..."
    git clone --depth=1 https://github.com/inference-sh/hermes-agent.git "$HERMES_DIR" 2>&1 | tail -3 \
        || { echo "  git clone failed — trying pip..."; python3 -m pip install --user hermes-agent 2>&1 | tail -3; }
fi
REMOTE

else
    # Shell mode: rsync from source node
    HERMES_DST="/home/${REMOTE_USER}/.hermes/hermes-agent/"

    if [[ "$DRY_RUN" == "1" ]]; then
        warn "DRY: rsync from ${SOURCE_NODE} → ${SSH_TARGET}:${HERMES_DST}"
    else
        rsync -az --delete \
            --exclude 'venv/' \
            --exclude '__pycache__/' \
            --exclude '*.pyc' \
            --exclude '.git/' \
            --exclude 'node_modules/' \
            -e "ssh $SSH_OPTS" \
            "/home/${REMOTE_USER}/.hermes/hermes-agent/" \
            "${REMOTE_USER}@${SSH_TARGET}:${HERMES_DST}" \
            && success "hermes-agent synced to $TARGET_HOST" \
            || die "rsync failed"
    fi
fi

# Always copy the extract script
if [[ "$DRY_RUN" == "0" ]]; then
    _scp "$EXTRACT_SCRIPT" "/tmp/extract-openclaw-keys.py"
fi

# ── Step 2: Create venv + install deps ───────────────────────────────────────
header "Step 2: Python venv + dependencies"

remote_script "Create venv and install deps" << 'REMOTE'
set -euo pipefail
HERMES_DIR="$HOME/.hermes/hermes-agent"

if [[ ! -d "$HERMES_DIR" ]]; then
    echo "  hermes-agent not found at $HERMES_DIR — was Step 1 successful?"
    exit 1
fi

if [[ ! -f "$HERMES_DIR/venv/bin/python" ]] || [[ ! -f "$HERMES_DIR/venv/bin/pip" ]]; then
    [[ -d "$HERMES_DIR/venv" ]] && rm -rf "$HERMES_DIR/venv"
    echo "  Creating venv..."
    python3 -m venv "$HERMES_DIR/venv"
    "$HERMES_DIR/venv/bin/python" -m ensurepip --upgrade 2>/dev/null || true
    "$HERMES_DIR/venv/bin/pip" install --upgrade pip --quiet
fi

echo "  Installing deps..."
if [[ -f "$HERMES_DIR/pyproject.toml" ]]; then
    "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR[all]" 2>&1 | tail -3 \
    || "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR" 2>&1 | tail -3
elif [[ -f "$HERMES_DIR/requirements.txt" ]]; then
    "$HERMES_DIR/venv/bin/pip" install -q -r "$HERMES_DIR/requirements.txt" 2>&1 | tail -3
fi
echo "  venv ready"
REMOTE

# ── Step 3: Extract keys from OpenClaw on target ─────────────────────────────
header "Step 3: Extract OpenClaw API keys"

if [[ "$DRY_RUN" == "0" ]]; then
    OC_KEYS=$(remote "run extract-openclaw-keys.py" \
        "python3 /tmp/extract-openclaw-keys.py 2>/dev/null" || true)
    if [[ -z "$OC_KEYS" ]]; then
        warn "No keys extracted from OpenClaw on $TARGET_HOST"
    else
        KEY_COUNT=$(echo "$OC_KEYS" | grep -c '=' || true)
        success "Extracted $KEY_COUNT key(s) from OpenClaw"
    fi
else
    warn "DRY: would extract keys via extract-openclaw-keys.py"
    OC_KEYS=""
fi

# ── Step 4: Seed ~/.hermes/.env ───────────────────────────────────────────────
header "Step 4: Seed ~/.hermes/.env"

if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY: would write merged .env to $TARGET_HOST:~/.hermes/.env"
else
    TMPENV=$(mktemp)
    trap "rm -f $TMPENV" EXIT

    if [[ "$STANDALONE" == "0" ]]; then
        # Shell mode: start with runner's shared keys, skip DISCORD_BOT_TOKEN
        ENV_SOURCE="$HOME/.hermes/.env"
        if [[ -f "$ENV_SOURCE" ]]; then
            grep -v '^DISCORD_BOT_TOKEN=' "$ENV_SOURCE" > "$TMPENV" 2>/dev/null || true
        else
            warn "No shared .env found at $ENV_SOURCE — using only OpenClaw keys"
        fi
    fi
    # (standalone: TMPENV starts empty; all keys come from OpenClaw)

    # Overlay per-node keys from OpenClaw
    if [[ -n "$OC_KEYS" ]]; then
        echo "$OC_KEYS" >> "$TMPENV"
    fi

    remote "ensure ~/.hermes exists" "mkdir -p ~/.hermes"
    _scp "$TMPENV" "/tmp/hermes_env_new"

    # On remote: append + deduplicate (last-write-wins per key)
    remote "Merge and deduplicate .env" '
        mkdir -p ~/.hermes
        cat /tmp/hermes_env_new >> ~/.hermes/.env
        python3 -c "
import os
path = os.path.expanduser('"'"'~/.hermes/.env'"'"')
seen = {}
for line in open(path).readlines():
    k = line.split('"'"'='"'"', 1)[0].strip()
    if k:
        seen[k] = line
with open(path, '"'"'w'"'"') as f:
    for line in seen.values():
        f.write(line if line.endswith('"'"'\n'"'"') else line + '"'"'\n'"'"')
print(f'"'"'  .env: {len(seen)} keys'"'"')
"
        rm -f /tmp/hermes_env_new
    '
    success ".env written"
fi

# ── Step 5: Seed config.yaml ──────────────────────────────────────────────────
header "Step 5: Seed ~/.hermes/config.yaml"

# Get node name from hostmap (gracefully handle missing hostmap for standalone)
NODE_NAME=$(python3 -c "
import json, os
hmap = '$REPO_ROOT/hostmap.json'
if os.path.exists(hmap):
    nodes = json.load(open(hmap)).get('nodes', [])
    match = [n for n in nodes if n.get('hostname') == '$TARGET_HOST']
    print(match[0]['name'] if match else '$TARGET_HOST')
else:
    print('$TARGET_HOST')
" 2>/dev/null || echo "$TARGET_HOST")

remote_script "Write config.yaml" << REMOTE
set -euo pipefail
mkdir -p "\$HOME/.hermes"
CONFIG="\$HOME/.hermes/config.yaml"

if [[ -f "\$CONFIG" ]]; then
    echo "  config.yaml exists — patching"
    python3 << 'PYEOF'
import yaml, os
path = os.path.expanduser("~/.hermes/config.yaml")
with open(path) as f:
    cfg = yaml.safe_load(f) or {}

discord = cfg.setdefault("discord", {})
discord.setdefault("require_mention", False)
discord.setdefault("auto_thread", False)

display = cfg.setdefault("display", {})
display.setdefault("tool_progress", "off")

model = cfg.setdefault("model", {})
model.setdefault("default", "anthropic/claude-sonnet-4-6")

# Fix: openclaw extract writes DISCORD_HOME_CHANNEL_ID but the gateway
# reads DISCORD_HOME_CHANNEL — copy the value under the correct key.
env_path = os.path.expanduser("~/.hermes/.env")
if os.path.exists(env_path):
    env_vars = {}
    for line in open(env_path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            env_vars[k.strip()] = v.strip()
    ch_id = env_vars.get("DISCORD_HOME_CHANNEL_ID", "")
    if ch_id and not env_vars.get("DISCORD_HOME_CHANNEL", ""):
        # Append correct key to .env
        with open(env_path, "a") as f:
            f.write(f"\nDISCORD_HOME_CHANNEL={ch_id}\n")
        print(f"  fixed: DISCORD_HOME_CHANNEL={ch_id}")

with open(path, "w") as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
print("  patched")
PYEOF
else
    echo "  Writing fresh config.yaml for ${NODE_NAME}"
    cat > "\$CONFIG" << 'YAML'
# Hermes config — seeded by migrate-to-hermes.sh
model:
  default: anthropic/claude-sonnet-4-6

discord:
  require_mention: false
  auto_thread: false

display:
  tool_progress: off
YAML
    echo "  config.yaml written"
fi
REMOTE

# ── Step 6: Migrate phext + identity files ────────────────────────────────────
header "Step 6: Migrate phext files and identity"

remote_script "Copy phexts and SOUL.md from ~/.openclaw/workspace" << 'REMOTE'
set -euo pipefail
SRC="$HOME/.openclaw/workspace"
DST="$HOME/.hermes"
mkdir -p "$DST/phexts" "$DST/memories"

if [[ ! -d "$SRC" ]]; then
    echo "  No ~/.openclaw/workspace found — skipping phext/identity migration"
else
    # Phext files
    shopt -s nullglob
    phexts=("$SRC"/*.phext)
    phexts_sub=("$SRC"/phexts/*.phext)
    all_phexts=("${phexts[@]}" "${phexts_sub[@]}")
    copied=0
    for f in "${all_phexts[@]}"; do
        [[ -f "$f" ]] && cp -u "$f" "$DST/phexts/" && ((copied++)) || true
    done
    echo "  phexts: copied $copied file(s)"

    # Identity files
    for f in SOUL.md IDENTITY.md USER.md BOOTSTRAP.md HEARTBEAT.md PROGRAMMING.md; do
        [[ -f "$SRC/$f" ]] && cp -u "$SRC/$f" "$DST/$f" && echo "  copied $f" || true
    done

    # Memory dir
    [[ -d "$SRC/memory" ]] && cp -ru "$SRC/memory/." "$DST/memories/" 2>/dev/null && echo "  copied memory/" || true
fi
REMOTE

# ── Step 7: Install hermes-gateway.service ────────────────────────────────────
header "Step 7: Install systemd service"

remote_script "Install hermes-gateway.service" << 'REMOTE'
set -euo pipefail
HERMES_DIR="$HOME/.hermes/hermes-agent"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/hermes-gateway.service"
mkdir -p "$SERVICE_DIR"

if [[ ! -f "$SERVICE_FILE" ]]; then
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Hermes Agent Gateway - Messaging Platform Integration
After=network.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${HERMES_DIR}/venv/bin/python -m hermes_cli.main gateway run --replace
WorkingDirectory=${HERMES_DIR}
Environment="PATH=${HERMES_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="VIRTUAL_ENV=${HERMES_DIR}/venv"
Environment="HERMES_HOME=${HOME}/.hermes"
Restart=on-failure
RestartSec=30
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
    echo "  service file written"
else
    echo "  service file already present"
fi

systemctl --user daemon-reload
systemctl --user enable hermes-gateway.service
echo "  hermes-gateway.service enabled"
REMOTE

# ── Step 8: Stop OpenClaw ─────────────────────────────────────────────────────
header "Step 8: Stop OpenClaw"

remote_script "Disable openclaw-gateway.service" << 'REMOTE'
set -euo pipefail
for svc in openclaw-gateway openclaw openclaw.service mirrorborn-openclaw; do
    if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
        systemctl --user stop "$svc"    && echo "  stopped $svc"
        systemctl --user disable "$svc" && echo "  disabled $svc" || true
    fi
done
# Remove any auto-start symlinks left behind
for f in "$HOME/.config/systemd/user/default.target.wants"/openclaw*.service; do
    [[ -L "$f" ]] && rm -f "$f" && echo "  removed symlink: $(basename $f)"
done
pgrep -f "openclaw" > /dev/null 2>&1 && pkill -f "openclaw" && echo "  killed stray openclaw procs" || true
echo "  OpenClaw stopped"
REMOTE

# ── Step 9: Start Hermes + verify ─────────────────────────────────────────────
header "Step 9: Start Hermes gateway"

remote_script "Start and verify hermes-gateway" << 'REMOTE'
set -euo pipefail
systemctl --user restart hermes-gateway.service
sleep 4
if systemctl --user is-active --quiet hermes-gateway.service; then
    echo "  hermes-gateway: running ✓"
else
    echo "  hermes-gateway FAILED — last 20 log lines:"
    journalctl --user -u hermes-gateway.service -n 20 --no-pager
    exit 1
fi
REMOTE

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Migration complete: ${TARGET_HOST}${NC}"
echo ""
if [[ "$_is_local" == "1" ]]; then
    echo -e "  Gateway logs:  journalctl --user -u hermes-gateway -f"
else
    echo -e "  Gateway logs:  ssh ${REMOTE_USER}@${SSH_TARGET} 'journalctl --user -u hermes-gateway -f'"
fi
echo ""
