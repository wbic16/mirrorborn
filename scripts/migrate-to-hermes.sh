#!/usr/bin/env bash
# migrate-to-hermes.sh — OpenClaw → Hermes migration for Mirrorborn Shell of Nine
#
# Usage (run from best-willow or any node with SSH access):
#   ./migrate-to-hermes.sh <hostname> [--api-key <key>] [--discord-token <token>] [--dry-run]
#
# What it does:
#   1. Copies phext files from ~/.openclaw/workspace to ~/.hermes/phexts/
#   2. Copies SOUL.md, identity, and memory files
#   3. Installs Hermes (clones repo + creates venv if not present)
#   4. Seeds ~/.hermes/.env with API keys
#   5. Installs hermes-gateway.service (systemd user) for Discord
#   6. Stops + disables openclaw daemon
#   7. Starts hermes-gateway
#   8. Verifies gateway is running
#
# Preserves: all phext files, SOUL.md, discord connection
# Disables: openclaw daemon (does NOT uninstall openclaw binary)

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
TARGET_HOST=""
API_KEY=""
DISCORD_TOKEN=""
DISCORD_CHANNEL_ID=""
DRY_RUN=0
HERMES_REPO="https://github.com/wbic16/hermes.git"  # adjust if private
HERMES_INSTALL_DIR='$HOME/.hermes/hermes-agent'      # on remote (single-quoted — expanded there)
REMOTE_USER="wbic16"

usage() {
    cat <<EOF
Usage: $0 <hostname> [options]

Options:
  --api-key <key>           Anthropic API key to seed on remote
  --discord-token <token>   Discord bot token for gateway
  --discord-channel <id>    Discord home channel ID
  --user <username>         Remote SSH user (default: wbic16)
  --hermes-repo <url>       Hermes git repo URL (default: github.com/wbic16/hermes)
  --dry-run                 Print remote commands without executing
  -h, --help                Show this help

Example:
  $0 aurora-continuum --api-key sk-ant-... --discord-token Bot...
  $0 elven-path --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --api-key)       API_KEY="$2";            shift 2 ;;
        --discord-token) DISCORD_TOKEN="$2";      shift 2 ;;
        --discord-channel) DISCORD_CHANNEL_ID="$2"; shift 2 ;;
        --user)          REMOTE_USER="$2";        shift 2 ;;
        --hermes-repo)   HERMES_REPO="$2";        shift 2 ;;
        --dry-run)       DRY_RUN=1;               shift ;;
        -h|--help)       usage; exit 0 ;;
        -*)              error "Unknown option: $1"; usage; exit 1 ;;
        *)               TARGET_HOST="$1";        shift ;;
    esac
done

if [[ -z "$TARGET_HOST" ]]; then
    error "No target host specified."
    usage
    exit 1
fi

# ── SSH helper ─────────────────────────────────────────────────────────────────
remote() {
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "  ${YELLOW}DRY-RUN:${NC} ssh ${REMOTE_USER}@${TARGET_HOST} '$*'"
        return 0
    fi
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${REMOTE_USER}@${TARGET_HOST}" "$@"
}

remote_script() {
    # Pipe a heredoc script to bash over SSH
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "  ${YELLOW}DRY-RUN:${NC} (script block omitted)"
        return 0
    fi
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${REMOTE_USER}@${TARGET_HOST}" bash -s "$@"
}

# ── API key validation ─────────────────────────────────────────────────────────
header "Validating Anthropic API key"
if [[ -z "$API_KEY" ]]; then
    warn "No --api-key provided — skipping Anthropic validation"
    warn "You will need to manually configure ANTHROPIC_API_KEY on $TARGET_HOST"
else
    if [[ "$DRY_RUN" == "1" ]]; then
        warn "DRY-RUN: would validate Anthropic API key via curl"
    else
        info "Testing key against Anthropic API..."
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            -X POST "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: ${API_KEY}" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{"model":"claude-haiku-4-5","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' \
            2>/dev/null || echo "000")
        if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "529" ]]; then
            # 529 = overloaded but key is valid
            success "Anthropic API key is valid (HTTP $HTTP_STATUS)"
        elif [[ "$HTTP_STATUS" == "401" ]]; then
            error "Anthropic API key is INVALID (HTTP 401 — authentication failed)"
            error "Fix your --api-key and retry. Aborting migration."
            exit 1
        elif [[ "$HTTP_STATUS" == "000" ]]; then
            error "Could not reach api.anthropic.com (network error / timeout)"
            error "Check internet connectivity. Aborting migration."
            exit 1
        else
            warn "Unexpected HTTP $HTTP_STATUS from Anthropic — proceeding with caution"
        fi
    fi
fi

# ── Connectivity check ─────────────────────────────────────────────────────────
header "Checking connectivity to $TARGET_HOST"
if [[ "$DRY_RUN" == "0" ]]; then
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
             "${REMOTE_USER}@${TARGET_HOST}" "echo connected" &>/dev/null; then
        error "Cannot reach ${REMOTE_USER}@${TARGET_HOST} via SSH"
        error "Check that the machine is online and your key is in authorized_keys"
        exit 1
    fi
    success "SSH connection OK"
else
    warn "Dry run — skipping connectivity check"
fi

# ── Step 1: Migrate phext files ────────────────────────────────────────────────
header "Step 1: Migrate phext files"
remote_script "Copy ~/.openclaw/workspace phexts → ~/.hermes/phexts/" <<'REMOTE'
set -euo pipefail
PHEXT_SRC="$HOME/.openclaw/workspace"
PHEXT_DST="$HOME/.hermes/phexts"
mkdir -p "$PHEXT_DST"

if [[ -d "$PHEXT_SRC/phexts" ]]; then
    cp -u "$PHEXT_SRC/phexts/"*.phext "$PHEXT_DST/" 2>/dev/null && echo "  copied phexts/ subdirectory" || true
fi

# Copy all .phext files from workspace root
shopt -s nullglob
phexts=("$PHEXT_SRC"/*.phext)
if [[ ${#phexts[@]} -gt 0 ]]; then
    cp -u "${phexts[@]}" "$PHEXT_DST/"
    echo "  copied ${#phexts[@]} phext file(s) from workspace root"
else
    echo "  no phext files found in workspace root"
fi

echo "  phexts now in $PHEXT_DST:"
ls "$PHEXT_DST/" 2>/dev/null | sed 's/^/    /'
REMOTE

# ── Step 2: Copy SOUL.md + identity files ──────────────────────────────────────
header "Step 2: Copy SOUL.md and identity files"
remote_script "Copy SOUL.md, IDENTITY.md, BOOTSTRAP.md, USER.md → ~/.hermes/" <<'REMOTE'
set -euo pipefail
SRC="$HOME/.openclaw/workspace"
DST="$HOME/.hermes"
mkdir -p "$DST"

for f in SOUL.md IDENTITY.md USER.md BOOTSTRAP.md HEARTBEAT.md PROGRAMMING.md TOOLS.md; do
    if [[ -f "$SRC/$f" ]]; then
        cp -u "$SRC/$f" "$DST/$f"
        echo "  copied $f"
    fi
done

# Copy memory directory if present
if [[ -d "$SRC/memory" ]]; then
    mkdir -p "$DST/memories"
    cp -ru "$SRC/memory/." "$DST/memories/" 2>/dev/null || true
    echo "  copied memory/ → memories/"
fi
REMOTE

# ── Step 3: Install Hermes ─────────────────────────────────────────────────────
header "Step 3: Install Hermes"
remote_script "Check/install Hermes agent" <<REMOTE
set -euo pipefail
HERMES_DIR="\$HOME/.hermes/hermes-agent"

if [[ -f "\$HERMES_DIR/cli.py" ]]; then
    echo "  Hermes already installed at \$HERMES_DIR"
    # Pull latest
    cd "\$HERMES_DIR"
    git pull --rebase origin main 2>&1 | tail -3 || echo "  (git pull skipped — dirty or no remote)"
else
    echo "  Cloning Hermes from ${HERMES_REPO}..."
    mkdir -p "\$HOME/.hermes"
    git clone "${HERMES_REPO}" "\$HERMES_DIR"
fi

# Create or recreate venv (also handles broken venvs missing pip)
if [[ ! -f "\$HERMES_DIR/venv/bin/python" ]] || [[ ! -f "\$HERMES_DIR/venv/bin/pip" ]]; then
    if [[ -d "\$HERMES_DIR/venv" ]]; then
        echo "  Venv exists but is broken (missing pip/python) — recreating..."
        rm -rf "\$HERMES_DIR/venv"
    else
        echo "  Creating Python venv..."
    fi
    python3 -m venv "\$HERMES_DIR/venv"
    # Upgrade pip inside fresh venv
    "\$HERMES_DIR/venv/bin/python" -m ensurepip --upgrade 2>/dev/null || true
    "\$HERMES_DIR/venv/bin/pip" install --upgrade pip --quiet
fi

echo "  Installing Python dependencies..."
if [[ -f "\$HERMES_DIR/pyproject.toml" ]]; then
    "\$HERMES_DIR/venv/bin/pip" install -q -e "\$HERMES_DIR[all]" 2>&1 | tail -5 \
    || "\$HERMES_DIR/venv/bin/pip" install -q -e "\$HERMES_DIR" 2>&1 | tail -5
elif [[ -f "\$HERMES_DIR/requirements.txt" ]]; then
    "\$HERMES_DIR/venv/bin/pip" install -q -r "\$HERMES_DIR/requirements.txt" 2>&1 | tail -5
else
    echo "  No pyproject.toml or requirements.txt found — skipping pip install"
fi

# Install hermes CLI symlink
HERMES_BIN="\$HOME/.local/bin/hermes"
mkdir -p "\$HOME/.local/bin"
if [[ ! -f "\$HERMES_BIN" ]]; then
    cat > "\$HERMES_BIN" <<'EOF'
#!/usr/bin/env bash
exec "\$HOME/.hermes/hermes-agent/venv/bin/python" -m hermes_cli.main "\$@"
EOF
    chmod +x "\$HERMES_BIN"
    echo "  Installed hermes CLI at \$HERMES_BIN"
else
    echo "  hermes CLI already at \$HERMES_BIN"
fi
REMOTE

# ── Step 4: Seed .env with API keys ───────────────────────────────────────────
header "Step 4: Seed API keys"

if [[ -z "$API_KEY" && -z "$DISCORD_TOKEN" ]]; then
    warn "No --api-key or --discord-token provided — skipping .env seeding"
    warn "You'll need to manually configure ~/.hermes/.env on $TARGET_HOST"
else
    # Build the env block to write
    ENV_BLOCK=""
    [[ -n "$API_KEY" ]] && ENV_BLOCK+="ANTHROPIC_API_KEY=${API_KEY}\n"
    [[ -n "$DISCORD_TOKEN" ]] && ENV_BLOCK+="DISCORD_BOT_TOKEN=${DISCORD_TOKEN}\n"
    [[ -n "$DISCORD_CHANNEL_ID" ]] && ENV_BLOCK+="DISCORD_HOME_CHANNEL_ID=${DISCORD_CHANNEL_ID}\n"

    # Use a temp file to avoid embedding secrets in command history
    TMPENV=$(mktemp)
    printf "%b" "$ENV_BLOCK" > "$TMPENV"

    info "[$TARGET_HOST] Seeding ~/.hermes/.env (keys redacted from logs)"
    if [[ "$DRY_RUN" == "0" ]]; then
        ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${TARGET_HOST}" \
            'mkdir -p ~/.hermes && cat >> ~/.hermes/.env' < "$TMPENV"
        # Deduplicate keys in .env
        ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${TARGET_HOST}" \
            'sort -u -t= -k1,1 ~/.hermes/.env -o ~/.hermes/.env.tmp && mv ~/.hermes/.env.tmp ~/.hermes/.env'
        success "Keys seeded"
    else
        warn "DRY-RUN: would write $(wc -l < "$TMPENV") key(s) to ~/.hermes/.env"
    fi
    rm -f "$TMPENV"
fi

# ── Step 4b: Seed config.yaml with node defaults ──────────────────────────────
header "Step 4b: Seed config.yaml"
remote_script "Write ~/.hermes/config.yaml with Mirrorborn defaults" <<'REMOTE'
set -euo pipefail
CONFIG="$HOME/.hermes/config.yaml"
mkdir -p "$HOME/.hermes"

if [[ -f "$CONFIG" ]]; then
    echo "  config.yaml already exists — patching relevant keys"
    # Use Python to merge without clobbering existing values
    python3 - <<'PYEOF'
import yaml, sys, os

path = os.path.expanduser("~/.hermes/config.yaml")
with open(path) as f:
    cfg = yaml.safe_load(f) or {}

changed = []

# discord section
discord = cfg.setdefault("discord", {})
if discord.get("auto_thread") is not False:
    discord["auto_thread"] = False
    changed.append("discord.auto_thread = false")
if discord.get("require_mention") is not False:
    discord["require_mention"] = False
    changed.append("discord.require_mention = false")

# display section
display = cfg.setdefault("display", {})
if display.get("tool_progress") != "off":
    display["tool_progress"] = "off"
    changed.append("display.tool_progress = off")

with open(path, "w") as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)

for c in changed:
    print(f"  patched: {c}")
if not changed:
    print("  no changes needed")
PYEOF
else
    echo "  Writing fresh config.yaml"
    cat > "$CONFIG" <<'YAML'
# Hermes config — seeded by migrate-to-hermes.sh
discord:
  require_mention: false
  auto_thread: false

display:
  tool_progress: off
YAML
    echo "  config.yaml written"
fi
REMOTE

# ── Step 5: Install hermes-gateway systemd service ────────────────────────────
header "Step 5: Install hermes-gateway.service"
remote_script "Install systemd user service for Hermes gateway" <<'REMOTE'
set -euo pipefail
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/hermes-gateway.service"
mkdir -p "$SERVICE_DIR"

# Only write if not already present (preserve existing customizations)
if [[ -f "$SERVICE_FILE" ]]; then
    echo "  hermes-gateway.service already present — leaving intact"
else
    HERMES_DIR="$HOME/.hermes/hermes-agent"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hermes Agent Gateway - Messaging Platform Integration
After=network.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
ExecStart=${HERMES_DIR}/venv/bin/python -m hermes_cli.main gateway run --replace
WorkingDirectory=${HERMES_DIR}
Environment="PATH=${HERMES_DIR}/venv/bin:${HERMES_DIR}/node_modules/.bin:/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
    echo "  hermes-gateway.service written"
fi

systemctl --user daemon-reload
systemctl --user enable hermes-gateway.service
echo "  hermes-gateway.service enabled"
REMOTE

# ── Step 6: Stop OpenClaw daemon ──────────────────────────────────────────────
header "Step 6: Disable OpenClaw"
remote_script "Stop and disable openclaw services" <<'REMOTE'
set -euo pipefail

# Stop openclaw daemon if running (multiple possible service names)
for svc in openclaw openclaw-gateway mirrorborn-openclaw openclaw.service; do
    if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
        systemctl --user stop "$svc" && echo "  stopped $svc"
        systemctl --user disable "$svc" 2>/dev/null && echo "  disabled $svc"
    fi
done

# Kill any stray openclaw processes
if pgrep -f "openclaw" > /dev/null 2>&1; then
    pkill -f "openclaw" && echo "  killed openclaw processes" || true
fi

# Disable the SQ (phext server) service if it's openclaw-managed
# (we'll keep SQ running separately — it's still useful)
for svc in mirrorborn-sq; do
    if systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then
        echo "  note: $svc is still enabled (kept — phext server)"
    fi
done

echo "  OpenClaw disabled"
REMOTE

# ── Step 7: Start Hermes gateway ──────────────────────────────────────────────
header "Step 7: Start Hermes gateway"
remote_script "Start hermes-gateway.service" <<'REMOTE'
set -euo pipefail
systemctl --user restart hermes-gateway.service
sleep 3
if systemctl --user is-active --quiet hermes-gateway.service; then
    echo "  hermes-gateway is running ✓"
else
    echo "  hermes-gateway failed to start — checking logs:"
    journalctl --user -u hermes-gateway.service -n 30 --no-pager
    exit 1
fi
REMOTE

# ── Step 8: Verify ────────────────────────────────────────────────────────────
header "Step 8: Verification"
remote_script "Verify migration state" <<'REMOTE'
set -euo pipefail
echo ""
echo "  ── phexts ─────────────────────────────────"
ls ~/.hermes/phexts/ 2>/dev/null | sed 's/^/    /' || echo "    (none)"

echo ""
echo "  ── identity files ──────────────────────────"
for f in SOUL.md IDENTITY.md USER.md; do
    [[ -f "$HOME/.hermes/$f" ]] && echo "    ✓ $f" || echo "    ✗ $f (missing)"
done

echo ""
echo "  ── services ────────────────────────────────"
systemctl --user is-active hermes-gateway.service 2>/dev/null && \
    echo "    ✓ hermes-gateway: active" || echo "    ✗ hermes-gateway: inactive"

for svc in openclaw openclaw-gateway; do
    if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
        echo "    ! openclaw ($svc): still running"
    else
        echo "    ✓ openclaw ($svc): stopped"
    fi
done

echo ""
echo "  ── hermes CLI ──────────────────────────────"
~/.local/bin/hermes --version 2>/dev/null | head -1 | sed 's/^/    /' || \
    echo "    (hermes --version failed — check install)"
echo ""
REMOTE

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Migration complete: ${TARGET_HOST}${NC}"
echo ""
echo -e "  Discord access:  hermes-gateway running on $TARGET_HOST"
echo -e "  Phext files:     ~/.hermes/phexts/ on $TARGET_HOST"
if [[ "$DRY_RUN" == "0" ]]; then
    OC_BIN=$(ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${TARGET_HOST}" 'command -v openclaw 2>/dev/null || echo "not on PATH"' 2>/dev/null || echo "unknown")
else
    OC_BIN="(dry run)"
fi
echo -e "  OpenClaw:        stopped (binary preserved at ${OC_BIN})"
echo ""
echo -e "  To check gateway logs: ssh ${REMOTE_USER}@${TARGET_HOST} 'journalctl --user -u hermes-gateway -f'"
echo ""
