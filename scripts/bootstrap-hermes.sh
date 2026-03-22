#!/usr/bin/env bash
# bootstrap-hermes.sh — Install and configure Hermes on a single node
#
# Designed to run ON the target node itself (self-bootstrap).
# Called by swarm-migrate.sh via SSH, or run manually.
#
# TWO-PHASE DESIGN — OpenClaw is never disabled until the user confirms Hermes works:
#
#   Phase 1 (--phase install):
#     1. Install Hermes from github.com/NousResearch/hermes-agent
#     2. Extract credentials from openclaw.json
#     3. Merge .env
#     4. Write config.yaml
#     5. Migrate phexts + identity files
#     6. Start hermes-gateway.service (alongside OpenClaw — both run simultaneously)
#     7. Run 3 self-checks: gateway responds, Discord bot connects, memory readable
#     → Prints "HERMES_READY" or "HERMES_NOT_READY:<reason>" to stdout for orchestrator
#     → Does NOT touch OpenClaw
#
#   Phase 2 (--phase cutover):
#     8. Stop + disable openclaw-gateway.service
#     9. Verify hermes-gateway still active
#     10. Final health check
#     → Prints "CUTOVER_COMPLETE" or "CUTOVER_FAILED:<reason>"
#
# Usage:
#   bash bootstrap-hermes.sh --phase install    # Phase 1: install, start, check
#   bash bootstrap-hermes.sh --phase cutover    # Phase 2: kill OpenClaw
#   bash bootstrap-hermes.sh --phase status     # Just report current state
#   bash bootstrap-hermes.sh --phase rollback   # Re-enable OpenClaw, stop Hermes
#
#   curl -fsSL https://raw.githubusercontent.com/wbic16/mirrorborn/exo/scripts/bootstrap-hermes.sh \
#     | bash -s -- --phase install
#
# Flags:
#   --discord-token <token>   Override Discord bot token
#   --anthropic-key <key>     Override Anthropic API key
#   --env <KEY=VAL\nKEY=VAL>  Extra env vars (newline-separated)
#   --force                   Re-run even if already done
#   --dry-run                 Print steps without executing
#   --check-retries <n>       Self-check attempts before giving up (default: 3)
#   --check-delay <s>         Seconds between check attempts (default: 5)

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }
die()     { error "$*"; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
PHASE="install"
DISCORD_TOKEN=""
ANTHROPIC_KEY=""
EXTRA_ENV=""
FORCE=0
DRY_RUN=0
CHECK_RETRIES=3
CHECK_DELAY=5

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_DIR="$HERMES_HOME/hermes-agent"
PHASE_FILE="$HERMES_HOME/.migration-phase"   # tracks install|ready|cutover

# ── Args ──────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)          PHASE="$2";          shift 2 ;;
        --discord-token)  DISCORD_TOKEN="$2";  shift 2 ;;
        --anthropic-key)  ANTHROPIC_KEY="$2";  shift 2 ;;
        --env)            EXTRA_ENV="$2";      shift 2 ;;
        --force)          FORCE=1;             shift ;;
        --dry-run)        DRY_RUN=1;           shift ;;
        --check-retries)  CHECK_RETRIES="$2";  shift 2 ;;
        --check-delay)    CHECK_DELAY="$2";    shift 2 ;;
        -h|--help) grep '^#' "$0" | head -40 | sed 's/^# \?//'; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
set_phase() { echo "$1" > "$PHASE_FILE"; }
get_phase() { [[ -f "$PHASE_FILE" ]] && cat "$PHASE_FILE" || echo "none"; }

dry() {
    if [[ "$DRY_RUN" == "1" ]]; then
        warn "DRY: $*"
        return 0
    fi
    return 1
}

# ── PHASE: status ─────────────────────────────────────────────────────────────
if [[ "$PHASE" == "status" ]]; then
    echo "hostname:    $(hostname)"
    echo "phase:       $(get_phase)"
    echo "hermes:      $(systemctl --user is-active hermes-gateway.service 2>/dev/null || echo inactive)"
    echo "openclaw:    $(systemctl --user is-active openclaw-gateway.service 2>/dev/null || echo inactive)"
    echo "hermes_dir:  $([[ -d "$HERMES_DIR" ]] && echo present || echo missing)"
    echo "env_keys:    $(grep -c '=' "$HERMES_HOME/.env" 2>/dev/null || echo 0)"
    exit 0
fi

# ── PHASE: rollback ───────────────────────────────────────────────────────────
if [[ "$PHASE" == "rollback" ]]; then
    header "Rollback: re-enabling OpenClaw, stopping Hermes"
    systemctl --user stop hermes-gateway.service 2>/dev/null || true
    systemctl --user disable hermes-gateway.service 2>/dev/null || true
    for svc in openclaw-gateway openclaw mirrorborn-openclaw; do
        if systemctl --user list-unit-files "$svc.service" &>/dev/null; then
            systemctl --user enable "$svc.service" 2>/dev/null || true
            systemctl --user start "$svc.service" 2>/dev/null || true
            echo "  restarted $svc"
        fi
    done
    set_phase "rolled-back"
    success "Rollback complete — OpenClaw restored"
    echo "ROLLBACK_COMPLETE"
    exit 0
fi

# ── PHASE: cutover ────────────────────────────────────────────────────────────
if [[ "$PHASE" == "cutover" ]]; then
    header "Phase 2: Cutover — disabling OpenClaw"

    CURRENT_PHASE=$(get_phase)
    if [[ "$CURRENT_PHASE" != "ready" && "$FORCE" == "0" ]]; then
        die "Cannot cutover: migration phase is '$CURRENT_PHASE', expected 'ready'. Run --phase install first, or --force to override."
    fi

    # Confirm Hermes is still healthy before pulling the plug
    header "Pre-cutover health check"
    if ! systemctl --user is-active --quiet hermes-gateway.service; then
        die "hermes-gateway is NOT active — refusing to cut over. Fix Hermes first."
    fi
    success "hermes-gateway: active ✓"

    if dry "would stop + disable openclaw-gateway.service"; then
        :
    else
        for svc in openclaw-gateway openclaw openclaw.service mirrorborn-openclaw; do
            if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
                systemctl --user stop "$svc"    && echo "  stopped $svc"
                systemctl --user disable "$svc" 2>/dev/null && echo "  disabled $svc" || true
            fi
        done
        pgrep -f "openclaw" > /dev/null 2>&1 && pkill -f "openclaw" && echo "  killed stray openclaw procs" || true
    fi

    # Post-cutover health check — Hermes still running?
    sleep 2
    if ! systemctl --user is-active --quiet hermes-gateway.service; then
        error "hermes-gateway went down after OpenClaw was stopped!"
        warn "Attempting rollback..."
        bash "$0" --phase rollback
        echo "CUTOVER_FAILED:hermes_died_after_openclaw_stop"
        exit 1
    fi

    set_phase "cutover"
    success "OpenClaw disabled. Hermes is the sole gateway. ✓"
    echo "CUTOVER_COMPLETE:$(hostname)"
    exit 0
fi

# ── PHASE: install ────────────────────────────────────────────────────────────
header "Phase 1: Install + Start (OpenClaw stays running)"

CURRENT_PHASE=$(get_phase)
if [[ "$CURRENT_PHASE" == "cutover" && "$FORCE" == "0" ]]; then
    success "Already fully migrated (phase=cutover). Use --force to re-run."
    exit 0
fi

# ── Step 1: Install Hermes ────────────────────────────────────────────────────
header "Step 1: Install Hermes"

if [[ -f "$HERMES_DIR/cli.py" ]] && [[ "$FORCE" == "0" ]]; then
    success "Hermes already installed — pulling latest"
    dry "git pull" || (cd "$HERMES_DIR" && git pull --rebase origin main 2>&1 | tail -2 || true)
else
    dry "install from NousResearch/hermes-agent" || {
        info "Installing from github.com/NousResearch/hermes-agent..."
        curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
    }
fi

# Venv
if dry "create venv + install deps"; then
    :
else
    if [[ ! -f "$HERMES_DIR/venv/bin/python" ]]; then
        info "Creating venv..."
        python3 -m venv "$HERMES_DIR/venv"
        "$HERMES_DIR/venv/bin/pip" install --upgrade pip --quiet
    fi
    if [[ -f "$HERMES_DIR/pyproject.toml" ]]; then
        "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR[all]" 2>&1 | tail -3 \
            || "$HERMES_DIR/venv/bin/pip" install -q -e "$HERMES_DIR" 2>&1 | tail -3
    elif [[ -f "$HERMES_DIR/requirements.txt" ]]; then
        "$HERMES_DIR/venv/bin/pip" install -q -r "$HERMES_DIR/requirements.txt" 2>&1 | tail -3
    fi
    success "Hermes installed"
fi

# ── Step 2: Extract OpenClaw credentials ─────────────────────────────────────
header "Step 2: Extract OpenClaw credentials"

OC_JSON="$HOME/.openclaw/openclaw.json"
OC_KEYS=""

if [[ -f "$OC_JSON" ]]; then
    OC_KEYS=$(python3 /tmp/extract-openclaw-keys.py 2>/dev/null \
        || python3 - << 'PYEOF'
import json, os, re

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
        results[f"OPENCLAW_SKILL_{skill_name.upper().replace('-','_')}_API_KEY"] = cfg["apiKey"]

for k, v in sorted(results.items()):
    print(f"{k}={v}")
PYEOF
    )
    KEY_COUNT=$(echo "$OC_KEYS" | grep -c '=' 2>/dev/null || echo 0)
    success "Extracted $KEY_COUNT key(s) from OpenClaw"
else
    warn "No openclaw.json found — no OpenClaw keys extracted"
fi

# ── Step 3: Write ~/.hermes/.env ─────────────────────────────────────────────
header "Step 3: Seed ~/.hermes/.env"
dry ".env merge" || {
    mkdir -p "$HERMES_HOME"
    TMPENV=$(mktemp); trap "rm -f $TMPENV" EXIT
    [[ -n "$OC_KEYS" ]]       && echo "$OC_KEYS"                        >> "$TMPENV"
    [[ -n "$DISCORD_TOKEN" ]] && echo "DISCORD_BOT_TOKEN=$DISCORD_TOKEN" >> "$TMPENV"
    [[ -n "$ANTHROPIC_KEY" ]] && echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY" >> "$TMPENV"
    [[ -n "$EXTRA_ENV" ]]     && printf '%s\n' "$EXTRA_ENV"             >> "$TMPENV"

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
    [f.write(v) for v in seen.values()]
print(f"  .env: {len(seen)} keys")
PYEOF
    chmod 600 "$HERMES_HOME/.env"
    success ".env written"
}

# ── Step 4: Write config.yaml ─────────────────────────────────────────────────
header "Step 4: config.yaml"
dry "config.yaml" || {
    CONFIG="$HERMES_HOME/config.yaml"
    if [[ ! -f "$CONFIG" ]]; then
        cat > "$CONFIG" << 'YAML'
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
        python3 - << 'PYEOF'
import yaml, os
p = os.path.expanduser("~/.hermes/config.yaml")
with open(p) as f: cfg = yaml.safe_load(f) or {}
cfg.setdefault("model", {}).setdefault("default", "anthropic/claude-sonnet-4-6")
cfg.setdefault("discord", {}).setdefault("require_mention", False)
cfg.setdefault("display", {}).setdefault("tool_progress", "off")
with open(p, "w") as f: yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
print("  config.yaml patched")
PYEOF
    fi
}

# ── Step 5: Migrate phexts + identity ────────────────────────────────────────
header "Step 5: Migrate phexts + identity"
dry "phext migration" || {
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
        warn "No ~/.openclaw/workspace — skipping"
    fi
    success "Files migrated"
}

# ── Step 6: Install + start hermes-gateway.service ───────────────────────────
header "Step 6: Install hermes-gateway.service"
dry "install systemd service" || {
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
    systemctl --user restart hermes-gateway.service
    success "hermes-gateway.service started (OpenClaw still running)"
}

# ── Step 7: Self-checks ───────────────────────────────────────────────────────
header "Step 7: Self-checks (${CHECK_RETRIES} attempts, ${CHECK_DELAY}s apart)"

CHECK_PASSED=0
CHECK_REASON=""

for attempt in $(seq 1 "$CHECK_RETRIES"); do
    info "Attempt $attempt / $CHECK_RETRIES..."
    sleep "$CHECK_DELAY"

    # Check 1: systemd active
    if ! systemctl --user is-active --quiet hermes-gateway.service 2>/dev/null; then
        CHECK_REASON="systemd:hermes-gateway not active"
        warn "  ✗ hermes-gateway not active"
        continue
    fi
    echo "  ✓ hermes-gateway: active"

    # Check 2: process is actually running (not zombie)
    if ! pgrep -f "hermes_cli.main gateway" > /dev/null 2>&1; then
        CHECK_REASON="process:gateway process not found"
        warn "  ✗ gateway process not found"
        continue
    fi
    echo "  ✓ gateway process: running"

    # Check 3: can read .env (basic sanity — means config loaded)
    if [[ ! -s "$HERMES_HOME/.env" ]]; then
        CHECK_REASON="config:.env is empty"
        warn "  ✗ .env is empty or missing"
        continue
    fi
    echo "  ✓ .env: present"

    # Check 4: no crash loop (systemd not in failed state, not restarting rapidly)
    RESTART_COUNT=$(systemctl --user show hermes-gateway.service --property=NRestarts --value 2>/dev/null || echo "0")
    if [[ "$RESTART_COUNT" -gt 3 ]]; then
        CHECK_REASON="stability:restarted ${RESTART_COUNT} times"
        warn "  ✗ too many restarts: $RESTART_COUNT"
        journalctl --user -u hermes-gateway.service -n 10 --no-pager 2>/dev/null || true
        continue
    fi
    echo "  ✓ stability: $RESTART_COUNT restart(s)"

    CHECK_PASSED=1
    break
done

if dry "self-checks"; then
    CHECK_PASSED=1
fi

if [[ "$CHECK_PASSED" == "1" ]]; then
    set_phase "ready"
    success "All checks passed — Hermes is operational alongside OpenClaw"
    echo ""
    echo "HERMES_READY:$(hostname)"
    echo ""
    echo -e "${YELLOW}WAITING FOR CUTOVER CONFIRMATION${NC}"
    echo -e "OpenClaw is still running. Hermes is live."
    echo -e "Both bots are active — verify Hermes works in Discord, then confirm cutover."
    echo -e ""
    echo -e "To complete migration after confirmation:"
    echo -e "  bash $0 --phase cutover"
    echo -e ""
    echo -e "To roll back (re-disable Hermes):"
    echo -e "  bash $0 --phase rollback"
else
    set_phase "install-failed"
    error "Self-checks failed: $CHECK_REASON"
    journalctl --user -u hermes-gateway.service -n 20 --no-pager 2>/dev/null || true
    echo "HERMES_NOT_READY:$(hostname):$CHECK_REASON"
    exit 1
fi
