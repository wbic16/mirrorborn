#!/usr/bin/env bash
# migrate-to-hermes.sh — Live OpenClaw → Hermes migration for one Mirrorborn node
#
# Designed to run entirely from elven-path (or any already-migrated node)
# with only SSH access. No Tailscale, no phone app, no terminal required.
# Invocable from Discord: "orin, migrate aurora-continuum"
#
# Usage:
#   ./migrate-to-hermes.sh <hostname>             # e.g. aurora-continuum
#   ./migrate-to-hermes.sh <hostname> --dry-run   # print steps without executing
#   ./migrate-to-hermes.sh <hostname> --force     # re-run even if Hermes already active
#
# What it does:
#   1. rsync hermes-agent from elven-path → target node
#   2. Create Python venv + install deps on target
#   3. Extract API keys from OpenClaw on target (extract-openclaw-keys.py)
#   4. Seed ~/.hermes/.env — per-node Discord token from OpenClaw, shared keys from elven-path
#   5. Seed ~/.hermes/config.yaml with Mirrorborn defaults
#   6. Migrate phext files and identity (SOUL.md etc.) from ~/.openclaw/workspace
#   7. Install + enable hermes-gateway.service (systemd user)
#   8. Stop + disable openclaw-gateway.service
#   9. Start hermes-gateway and verify
#
# Preserves: all phext files, SOUL.md, openclaw binary (not removed)
# Requires:  SSH key access to target, Python 3.11+, rsync

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
REMOTE_USER="wbic16"
SOURCE_NODE="elven-path"   # the already-migrated node we rsync hermes-agent from

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force)   FORCE=1;   shift ;;
        --user)    REMOTE_USER="$2"; shift 2 ;;
        --source)  SOURCE_NODE="$2"; shift 2 ;;
        -h|--help) grep '^#' "$0" | head -30 | sed 's/^# \?//'; exit 0 ;;
        -*)        die "Unknown option: $1" ;;
        *)         TARGET_HOST="$1"; shift ;;
    esac
done

[[ -z "$TARGET_HOST" ]] && die "No target host specified. Usage: $0 <hostname>"
[[ "$TARGET_HOST" == "$SOURCE_NODE" ]] && die "Target and source are the same node ($TARGET_HOST) — nothing to do."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract-openclaw-keys.py"
[[ -f "$EXTRACT_SCRIPT" ]] || die "Missing: $EXTRACT_SCRIPT"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

remote() {
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    [[ "$DRY_RUN" == "1" ]] && { echo -e "  ${YELLOW}DRY:${NC} $*"; return 0; }
    ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" "$@"
}

remote_script() {
    # Run a heredoc script on the remote via stdin
    local desc="$1"; shift
    info "[$TARGET_HOST] $desc"
    [[ "$DRY_RUN" == "1" ]] && { echo -e "  ${YELLOW}DRY:${NC} (script block)"; cat; return 0; }
    ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" bash -s "$@"
}

# ── Connectivity check ────────────────────────────────────────────────────────
header "Preflight: $TARGET_HOST"

if [[ "$DRY_RUN" == "0" ]]; then
    ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" "echo connected" > /dev/null 2>&1 \
        || die "Cannot reach ${REMOTE_USER}@${TARGET_HOST}.local via SSH"
    success "SSH OK"
fi

# Check if already migrated
if [[ "$FORCE" == "0" && "$DRY_RUN" == "0" ]]; then
    if ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" \
        "systemctl --user is-active hermes-gateway.service" > /dev/null 2>&1; then
        success "hermes-gateway already active on $TARGET_HOST — skipping (use --force to re-run)"
        exit 0
    fi
fi

# ── Step 1: rsync hermes-agent from source node ───────────────────────────────
header "Step 1: rsync hermes-agent → $TARGET_HOST"

HERMES_SRC="${REMOTE_USER}@${SOURCE_NODE}.local:/home/${REMOTE_USER}/.hermes/hermes-agent/"
HERMES_DST="/home/${REMOTE_USER}/.hermes/hermes-agent/"

if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY: rsync -az --delete $HERMES_SRC $TARGET_HOST:$HERMES_DST"
else
    # Run rsync FROM the target pulling from source, via SSH jump — or push from here
    # We're on elven-path, so push directly:
    rsync -az --delete \
        --exclude 'venv/' \
        --exclude '__pycache__/' \
        --exclude '*.pyc' \
        --exclude '.git/' \
        --exclude 'node_modules/' \
        -e "ssh $SSH_OPTS" \
        "/home/${REMOTE_USER}/.hermes/hermes-agent/" \
        "${REMOTE_USER}@${TARGET_HOST}.local:${HERMES_DST}" \
        && success "hermes-agent synced to $TARGET_HOST" \
        || die "rsync failed"

    # Also copy the extract script to the node
    scp $SSH_OPTS "$EXTRACT_SCRIPT" \
        "${REMOTE_USER}@${TARGET_HOST}.local:/tmp/extract-openclaw-keys.py" > /dev/null
fi

# ── Step 2: Create venv + install deps ───────────────────────────────────────
header "Step 2: Python venv + dependencies"

remote_script "Create venv and install deps" << 'REMOTE'
set -euo pipefail
HERMES_DIR="$HOME/.hermes/hermes-agent"

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
    OC_KEYS=$(ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" \
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

# Build the .env:
# - Start with elven-path's .env (shared keys: Anthropic, Firecrawl, etc.)
# - Overlay with per-node keys from OpenClaw (Discord token must be per-node)
# - DISCORD_BOT_TOKEN from OpenClaw takes precedence over elven-path's token
ENV_SOURCE="$HOME/.hermes/.env"
[[ -f "$ENV_SOURCE" ]] || die "Source .env not found at $ENV_SOURCE"

if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY: would write merged .env to $TARGET_HOST:~/.hermes/.env"
else
    # Build merged env in a temp file — never touches shell history
    TMPENV=$(mktemp)
    trap "rm -f $TMPENV" EXIT

    # Base: shared keys from elven-path (skip DISCORD_BOT_TOKEN — will come from OpenClaw)
    grep -v '^DISCORD_BOT_TOKEN=' "$ENV_SOURCE" > "$TMPENV" 2>/dev/null || true

    # Overlay: per-node keys from OpenClaw (DISCORD_BOT_TOKEN, BRAVE_SEARCH_API_KEY, etc.)
    if [[ -n "$OC_KEYS" ]]; then
        echo "$OC_KEYS" >> "$TMPENV"
    fi

    # Push to remote, dedup by key (last wins — OpenClaw overlay takes effect)
    ssh $SSH_OPTS "${REMOTE_USER}@${TARGET_HOST}.local" 'mkdir -p ~/.hermes' < /dev/null
    scp $SSH_OPTS "$TMPENV" "${REMOTE_USER}@${TARGET_HOST}.local:/tmp/hermes_env_new" > /dev/null

    # On remote: merge with any existing .env, deduplicate (last-write-wins per key)
    remote "Merge and deduplicate .env" '
        mkdir -p ~/.hermes
        cat /tmp/hermes_env_new >> ~/.hermes/.env
        # Deduplicate: keep last occurrence of each key
        python3 -c "
import sys
seen = {}
lines = open(\"$HOME/.hermes/.env\").readlines()
for line in lines:
    k = line.split(\"=\", 1)[0].strip()
    seen[k] = line
with open(\"$HOME/.hermes/.env\", \"w\") as f:
    for line in seen.values():
        f.write(line if line.endswith(\"\\n\") else line + \"\\n\")
print(f\"  .env: {len(seen)} keys\")
"
        rm -f /tmp/hermes_env_new
    '
    success ".env written"
fi

# ── Step 5: Seed config.yaml ──────────────────────────────────────────────────
header "Step 5: Seed ~/.hermes/config.yaml"

# Get node name from hostmap
NODE_NAME=$(python3 -c "
import json
nodes = json.load(open('$REPO_ROOT/hostmap.json'))['nodes']
match = [n for n in nodes if n['hostname'] == '$TARGET_HOST']
print(match[0]['name'] if match else '$TARGET_HOST')
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

# Phext files
shopt -s nullglob
phexts=("$SRC"/*.phext "$SRC"/phexts/*.phext 2>/dev/null)
copied=0
for f in "${phexts[@]}"; do
    [[ -f "$f" ]] && cp -u "$f" "$DST/phexts/" && ((copied++)) || true
done
echo "  phexts: copied $copied file(s)"

# Identity files
for f in SOUL.md IDENTITY.md USER.md BOOTSTRAP.md HEARTBEAT.md PROGRAMMING.md; do
    [[ -f "$SRC/$f" ]] && cp -u "$SRC/$f" "$DST/$f" && echo "  copied $f" || true
done

# Memory dir
[[ -d "$SRC/memory" ]] && cp -ru "$SRC/memory/." "$DST/memories/" 2>/dev/null && echo "  copied memory/" || true
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
echo -e "  Gateway logs:  ssh ${REMOTE_USER}@${TARGET_HOST}.local 'journalctl --user -u hermes-gateway -f'"
echo ""
