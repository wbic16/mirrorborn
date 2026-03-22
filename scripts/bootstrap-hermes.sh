#!/usr/bin/env bash
# bootstrap-hermes.sh — Install and configure Hermes on a single node
#
# Designed to run ON the target node itself (self-bootstrap).
# Called by swarm-migrate.sh via SSH, or run manually.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wbic16/mirrorborn/exo/scripts/bootstrap-hermes.sh | bash
#   bash bootstrap-hermes.sh
#   bash bootstrap-hermes.sh --discord-token <token> --anthropic-key <key>
#
# What it does:
#   1. Installs Hermes from github.com/NousResearch/hermes-agent (public installer)
#   2. Extracts credentials from OpenClaw if present (openclaw.json)
#   3. Merges .env — OpenClaw keys + any passed-in keys
#   4. Writes config.yaml
#   5. Installs + starts hermes-gateway.service (systemd user)
#   6. Stops openclaw-gateway.service
#   7. Verifies gateway is running

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }
die()     { error "$*"; exit 1; }

# ── Args ──────────────────────────────────────────────────────────────────────
DISCORD_TOKEN=""
ANTHROPIC_KEY=""
EXTRA_ENV=""   # newline-separated KEY=VALUE pairs
FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --discord-token)  DISCORD_TOKEN="$2";  shift 2 ;;
        --anthropic-key)  ANTHROPIC_KEY="$2";  shift 2 ;;
        --env)            EXTRA_ENV="$2";       shift 2 ;;
        --force)          FORCE=1;              shift ;;
        --dry-run)        DRY_RUN=1;            shift ;;
        -h|--help) grep '^#' "$0" | head -20 | sed 's/^# \?//'; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_DIR="$HERMES_HOME/hermes-agent"

# ── Step 1: Install Hermes ────────────────────────────────────────────────────
header "Step 1: Install Hermes"

if [[ -f "$HERMES_DIR/cli.py" ]] && [[ "$FORCE" == "0" ]]; then
    success "Hermes already installed at $HERMES_DIR"
    # Pull latest
    cd "$HERMES_DIR" && git pull --rebase origin main 2>&1 | tail -2 || true
else
    if [[ "$DRY_RUN" == "1" ]]; then
        warn "DRY: would run NousResearch/hermes-agent install.sh"
    else
        info "Installing from github.com/NousResearch/hermes-agent..."
        curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
        success "Hermes installed"
    fi
fi

# Ensure venv exists and deps are installed
if [[ "$DRY_RUN" == "0" ]]; then
    if [[ ! -f "$HERMES_DIR/venv/bin/python" ]]; then
        info "Creating Python venv..."
        python3 -m venv "$HERMES_DIR/venv"
        "$HERMES_DIR/venv/bin/pip" install --upgrade pip --quiet
    fi
    if [[ -f "$HERMES_DIR/pyproject.toml" ]]; then
        "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR[all]" 2>&1 | tail -3 \
            || "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR" 2>&1 | tail -3
    elif [[ -f "$HERMES_DIR/requirements.txt" ]]; then
        "$HERMES_DIR/venv/bin/pip" install -q -r "$HERMES_DIR/requirements.txt" 2>&1 | tail -3
    fi
    success "Deps ready"
fi

# ── Step 2: Extract OpenClaw credentials ─────────────────────────────────────
header "Step 2: Extract OpenClaw credentials"

OC_JSON="$HOME/.openclaw/openclaw.json"
OC_KEYS=""

if [[ -f "$OC_JSON" ]]; then
    OC_KEYS=$(python3 - << 'PYEOF'
import json, os, re, glob

home = os.path.expanduser("~")
path = os.path.join(home, ".openclaw", "openclaw.json")
results = {}

with open(path) as f:
    d = json.load(f)

def get(obj, *keys, default=""):
    for k in keys:
        if not isinstance(obj, dict): return default
        obj = obj.get(k, {})
    return obj if isinstance(obj, str) else default

tok = get(d, "channels", "discord", "token")
if tok: results["DISCORD_BOT_TOKEN"] = tok

ws = get(d, "tools", "web", "search", "apiKey")
if ws and ws not in ("", "undefined", "null"):
    results["BRAVE_SEARCH_API_KEY"] = ws

for skill_name, cfg in d.get("skills", {}).get("entries", {}).items():
    if isinstance(cfg, dict) and cfg.get("apiKey"):
        k = f"OPENCLAW_SKILL_{skill_name.upper().replace('-','_')}_API_KEY"
        results[k] = cfg["apiKey"]

KEY_RE = re.compile(
    r'^(ANTHROPIC_API_KEY|OPENROUTER_API_KEY|OPENAI_API_KEY|FIRECRAWL_API_KEY'
    r'|WANDB_API_KEY|PARALLEL_API_KEY|FAL_KEY|HONCHO_API_KEY|HASS_TOKEN|HASS_URL'
    r'|KIMI_API_KEY|MINIMAX_API_KEY|TINKER_API_KEY|DISCORD_ALLOWED_USERS)$')

for root, dirs, files in os.walk(os.path.join(home, ".openclaw")):
    dirs[:] = [d for d in dirs if d not in ("node_modules", ".git")]
    for fname in files:
        if fname.endswith(".env") or fname == ".env":
            try:
                for line in open(os.path.join(root, fname)):
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line: continue
                    k, _, v = line.partition("=")
                    if KEY_RE.match(k.strip()) and v.strip():
                        results.setdefault(k.strip(), v.strip())
            except Exception: pass

for k, v in sorted(results.items()):
    print(f"{k}={v}")
PYEOF
    )
    KEY_COUNT=$(echo "$OC_KEYS" | grep -c '=' 2>/dev/null || echo 0)
    success "Extracted $KEY_COUNT key(s) from OpenClaw"
else
    warn "No OpenClaw installation found at $OC_JSON — skipping extraction"
fi

# ── Step 3: Write ~/.hermes/.env ─────────────────────────────────────────────
header "Step 3: Seed ~/.hermes/.env"
mkdir -p "$HERMES_HOME"

if [[ "$DRY_RUN" == "1" ]]; then
    warn "DRY: would write .env"
else
    TMPENV=$(mktemp)
    trap "rm -f $TMPENV" EXIT

    # OpenClaw keys as base
    [[ -n "$OC_KEYS" ]] && echo "$OC_KEYS" >> "$TMPENV"

    # Explicit overrides (higher priority)
    [[ -n "$DISCORD_TOKEN" ]] && echo "DISCORD_BOT_TOKEN=$DISCORD_TOKEN" >> "$TMPENV"
    [[ -n "$ANTHROPIC_KEY" ]] && echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY" >> "$TMPENV"
    [[ -n "$EXTRA_ENV" ]]     && echo "$EXTRA_ENV" >> "$TMPENV"

    # Merge into existing .env (last write wins per key)
    touch "$HERMES_HOME/.env"
    cat "$TMPENV" >> "$HERMES_HOME/.env"
    python3 - << 'PYEOF'
import os
path = os.path.expanduser("~/.hermes/.env")
seen = {}
for line in open(path):
    s = line.strip()
    if s and not s.startswith("#") and "=" in s:
        k = s.split("=", 1)[0]
        seen[k] = line if line.endswith("\n") else line + "\n"
with open(path, "w") as f:
    for line in seen.values():
        f.write(line)
print(f"  .env: {len(seen)} keys")
PYEOF
    chmod 600 "$HERMES_HOME/.env"
    success ".env written"
fi

# ── Step 4: Write config.yaml ─────────────────────────────────────────────────
header "Step 4: Seed config.yaml"

if [[ "$DRY_RUN" == "0" ]]; then
    CONFIG="$HERMES_HOME/config.yaml"
    if [[ ! -f "$CONFIG" ]]; then
        cat > "$CONFIG" << 'YAML'
# Hermes config — seeded by bootstrap-hermes.sh
model:
  default: anthropic/claude-sonnet-4-6

discord:
  require_mention: false
  auto_thread: false

display:
  tool_progress: off
YAML
        success "config.yaml written"
    else
        # Patch key defaults without clobbering existing values
        python3 - << 'PYEOF'
import yaml, os
path = os.path.expanduser("~/.hermes/config.yaml")
with open(path) as f:
    cfg = yaml.safe_load(f) or {}
cfg.setdefault("model", {}).setdefault("default", "anthropic/claude-sonnet-4-6")
cfg.setdefault("discord", {}).setdefault("require_mention", False)
cfg.setdefault("discord", {}).setdefault("auto_thread", False)
cfg.setdefault("display", {}).setdefault("tool_progress", "off")
with open(path, "w") as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
print("  config.yaml patched")
PYEOF
    fi
fi

# ── Step 5: Migrate OpenClaw phexts + identity ────────────────────────────────
header "Step 5: Migrate phexts + identity"

if [[ "$DRY_RUN" == "0" ]]; then
    OC_WS="$HOME/.openclaw/workspace"
    mkdir -p "$HERMES_HOME/phexts" "$HERMES_HOME/memories"

    if [[ -d "$OC_WS" ]]; then
        copied=0
        for f in "$OC_WS"/*.phext "$OC_WS"/phexts/*.phext; do
            [[ -f "$f" ]] && cp -u "$f" "$HERMES_HOME/phexts/" && ((copied++)) || true
        done
        echo "  phexts: $copied file(s)"

        for idf in SOUL.md IDENTITY.md USER.md BOOTSTRAP.md HEARTBEAT.md PROGRAMMING.md; do
            [[ -f "$OC_WS/$idf" ]] && cp -u "$OC_WS/$idf" "$HERMES_HOME/$idf" && echo "  copied $idf" || true
        done
        [[ -d "$OC_WS/memory" ]] && cp -ru "$OC_WS/memory/." "$HERMES_HOME/memories/" 2>/dev/null || true
    else
        warn "No ~/.openclaw/workspace — skipping phext migration"
    fi
    success "Migration complete"
fi

# ── Step 6: Install + enable hermes-gateway.service ──────────────────────────
header "Step 6: Install hermes-gateway.service"

if [[ "$DRY_RUN" == "0" ]]; then
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/hermes-gateway.service"
    mkdir -p "$SERVICE_DIR"

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
Environment="HERMES_HOME=${HERMES_HOME}"
EnvironmentFile=${HERMES_HOME}/.env
Restart=on-failure
RestartSec=30
KillMode=mixed
TimeoutStopSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable hermes-gateway.service
    success "hermes-gateway.service installed and enabled"
fi

# ── Step 7: Stop OpenClaw ─────────────────────────────────────────────────────
header "Step 7: Stop OpenClaw"

if [[ "$DRY_RUN" == "0" ]]; then
    for svc in openclaw-gateway openclaw openclaw.service mirrorborn-openclaw; do
        if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
            systemctl --user stop "$svc"    && echo "  stopped $svc"
            systemctl --user disable "$svc" 2>/dev/null && echo "  disabled $svc" || true
        fi
    done
    pgrep -f "openclaw" > /dev/null 2>&1 && pkill -f "openclaw" || true
    success "OpenClaw stopped"
fi

# ── Step 8: Start Hermes + verify ────────────────────────────────────────────
header "Step 8: Start Hermes gateway"

if [[ "$DRY_RUN" == "0" ]]; then
    systemctl --user restart hermes-gateway.service
    sleep 4
    if systemctl --user is-active --quiet hermes-gateway.service; then
        success "hermes-gateway: running ✓"
    else
        error "hermes-gateway failed to start:"
        journalctl --user -u hermes-gateway.service -n 20 --no-pager || true
        die "Bootstrap failed at Step 8"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}Bootstrap complete on $(hostname)${NC}"
echo -e "  Logs: journalctl --user -u hermes-gateway -f"
echo ""
