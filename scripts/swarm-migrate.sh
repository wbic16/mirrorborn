#!/usr/bin/env bash
# swarm-migrate.sh — Migrate any OpenClaw swarm to Hermes
#
# Works for Mirrorborn Shell of Nine AND any other OpenClaw deployment.
# Tries connection methods in order until one works:
#   1. SSH via mDNS (.local) — LAN only, no VPN needed
#   2. SSH via Tailscale hostname — VPN mesh
#   3. SSH via Terminus relay — cloud fallback
#   4. Print manual bootstrap URL — user pastes into phone terminal
#
# Invocable from Discord (no terminal, no VPN required from the user's side):
#   "orin, migrate all nodes"
#   "orin, migrate <hostname>"
#   "orin, migrate swarm --hosts aurora-continuum,halycon-vector"
#
# Usage:
#   ./swarm-migrate.sh                                  # migrate hostmap.json nodes
#   ./swarm-migrate.sh --hosts host1,host2,host3        # explicit host list
#   ./swarm-migrate.sh --host aurora-continuum          # single node
#   ./swarm-migrate.sh --dry-run                        # preview
#   ./swarm-migrate.sh --force                          # re-migrate already-done nodes
#   ./swarm-migrate.sh --tailscale-domain ts.net        # custom Tailscale domain
#   ./swarm-migrate.sh --terminus-url wss://...         # Terminus relay URL
#   ./swarm-migrate.sh --env-file /path/to/.env         # extra keys to seed
#
# Requirements (on this node):
#   - SSH key access to targets (at least one of: LAN/Tailscale/Terminus)
#   - python3 available locally
#   - curl available (for bootstrap script delivery)
#
# No requirements on target nodes beyond:
#   - SSH daemon running
#   - python3 + pip available
#   - systemd user session enabled

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }
note()    { echo -e "${BLUE}[i]${NC} $*"; }
die()     { error "$*"; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap-hermes.sh"
HOSTMAP="$REPO_ROOT/hostmap.json"
REMOTE_USER="wbic16"
TAILSCALE_DOMAIN=""           # e.g. "tail1234abc.ts.net"
TERMINUS_URL=""               # e.g. "wss://terminus.example.com"
ENV_FILE=""                   # extra .env to seed on all nodes
EXPLICIT_HOSTS=""             # comma-separated override
SINGLE_HOST=""
DRY_RUN=0
FORCE=0
SSH_TIMEOUT=8

# Bootstrap script source — prefer local, fall back to GitHub raw
BOOTSTRAP_URL="https://raw.githubusercontent.com/wbic16/mirrorborn/exo/scripts/bootstrap-hermes.sh"

# ── Args ──────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hosts)           EXPLICIT_HOSTS="$2";    shift 2 ;;
        --host)            SINGLE_HOST="$2";       shift 2 ;;
        --user)            REMOTE_USER="$2";       shift 2 ;;
        --tailscale-domain) TAILSCALE_DOMAIN="$2"; shift 2 ;;
        --terminus-url)    TERMINUS_URL="$2";      shift 2 ;;
        --env-file)        ENV_FILE="$2";          shift 2 ;;
        --dry-run)         DRY_RUN=1;              shift ;;
        --force)           FORCE=1;                shift ;;
        --timeout)         SSH_TIMEOUT="$2";       shift 2 ;;
        -h|--help)         grep '^#' "$0" | head -40 | sed 's/^# \?//'; exit 0 ;;
        -*) die "Unknown option: $1" ;;
        *)  SINGLE_HOST="$1"; shift ;;
    esac
done

# ── Load extra env if provided ────────────────────────────────────────────────
EXTRA_ENV_CONTENT=""
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    EXTRA_ENV_CONTENT=$(grep -v '^#' "$ENV_FILE" | grep '=' || true)
    info "Loaded $(echo "$EXTRA_ENV_CONTENT" | grep -c '=' || echo 0) extra env vars from $ENV_FILE"
fi

# ── Build host list ───────────────────────────────────────────────────────────
if [[ -n "$SINGLE_HOST" ]]; then
    HOSTS=("$SINGLE_HOST")
elif [[ -n "$EXPLICIT_HOSTS" ]]; then
    IFS=',' read -ra HOSTS <<< "$EXPLICIT_HOSTS"
elif [[ -f "$HOSTMAP" ]]; then
    # Read from hostmap.json — skip known-offline nodes
    mapfile -t HOSTS < <(python3 - "$HOSTMAP" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
skip = {"lighthouse-omen", "chrysalis-hub", "uncanny-valley"}
for n in d["nodes"]:
    if n["hostname"] not in skip:
        print(n["hostname"])
PYEOF
    )
else
    die "No hosts specified and no hostmap.json found at $HOSTMAP"
fi

# Remove current node from targets
CURRENT_HOST=$(hostname)
FILTERED_HOSTS=()
for h in "${HOSTS[@]}"; do
    [[ "$h" == "$CURRENT_HOST" ]] && continue
    FILTERED_HOSTS+=("$h")
done
HOSTS=("${FILTERED_HOSTS[@]}")

# ── Connection probe: find a working SSH address for a host ───────────────────
probe_connection() {
    local host="$1"
    local user="$2"
    local opts="-o StrictHostKeyChecking=no -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes"

    # 1. mDNS (.local) — LAN, no VPN
    if ssh $opts "${user}@${host}.local" "echo ok" > /dev/null 2>&1; then
        echo "mdns:${host}.local"
        return 0
    fi

    # 2. Bare hostname — works on same subnet with DNS
    if ssh $opts "${user}@${host}" "echo ok" > /dev/null 2>&1; then
        echo "hostname:${host}"
        return 0
    fi

    # 3. Tailscale — VPN mesh
    if [[ -n "$TAILSCALE_DOMAIN" ]]; then
        local ts_addr="${host}.${TAILSCALE_DOMAIN}"
        if ssh $opts "${user}@${ts_addr}" "echo ok" > /dev/null 2>&1; then
            echo "tailscale:${ts_addr}"
            return 0
        fi
    elif command -v tailscale > /dev/null 2>&1; then
        # Auto-detect Tailscale domain
        local ts_domain
        ts_domain=$(tailscale status --json 2>/dev/null | python3 -c \
            "import json,sys; d=json.load(sys.stdin); print(d.get('MagicDNSSuffix',''))" 2>/dev/null || echo "")
        if [[ -n "$ts_domain" ]]; then
            local ts_addr="${host}.${ts_domain}"
            if ssh $opts "${user}@${ts_addr}" "echo ok" > /dev/null 2>&1; then
                echo "tailscale:${ts_addr}"
                return 0
            fi
        fi
    fi

    # 4. Terminus relay — cloud fallback
    if [[ -n "$TERMINUS_URL" ]]; then
        # Terminus uses websocket tunnels; check if terminus CLI is available
        if command -v terminus > /dev/null 2>&1; then
            if terminus connect --url "$TERMINUS_URL" --host "$host" --check > /dev/null 2>&1; then
                echo "terminus:${host}"
                return 0
            fi
        fi
    fi

    # No path found
    echo "unreachable:"
    return 1
}

# ── Remote execution via detected path ───────────────────────────────────────
remote_exec() {
    local conn_type="$1"
    local addr="$2"
    local user="$3"
    shift 3
    local opts="-o StrictHostKeyChecking=no -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes"

    case "$conn_type" in
        mdns|hostname|tailscale)
            ssh $opts "${user}@${addr}" "$@"
            ;;
        terminus)
            terminus exec --url "$TERMINUS_URL" --host "$addr" --user "$user" -- "$@"
            ;;
    esac
}

remote_scp() {
    local conn_type="$1"
    local addr="$2"
    local user="$3"
    local src="$4"
    local dst="$5"
    local opts="-o StrictHostKeyChecking=no -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes"

    case "$conn_type" in
        mdns|hostname|tailscale)
            scp $opts "$src" "${user}@${addr}:${dst}"
            ;;
        terminus)
            terminus scp --url "$TERMINUS_URL" --host "$addr" --user "$user" "$src" "$dst"
            ;;
    esac
}

# ── Migrate one host ──────────────────────────────────────────────────────────
migrate_host() {
    local host="$1"

    header "Migrating: $host"

    # Probe connection
    info "Probing connection methods..."
    local probe_result
    probe_result=$(probe_connection "$host" "$REMOTE_USER") || true
    local conn_type="${probe_result%%:*}"
    local conn_addr="${probe_result##*:}"

    if [[ "$conn_type" == "unreachable" || -z "$conn_addr" ]]; then
        warn "Cannot reach $host via any method (LAN, Tailscale, Terminus)"
        note "Manual fallback: on $host, run:"
        note "  curl -fsSL $BOOTSTRAP_URL | bash"
        return 1
    fi

    case "$conn_type" in
        mdns)      success "Connected via LAN mDNS ($conn_addr)" ;;
        hostname)  success "Connected via hostname ($conn_addr)" ;;
        tailscale) success "Connected via Tailscale ($conn_addr)" ;;
        terminus)  success "Connected via Terminus relay ($conn_addr)" ;;
    esac

    if [[ "$DRY_RUN" == "1" ]]; then
        warn "DRY: would run bootstrap-hermes.sh on $host via $conn_type"
        return 0
    fi

    # Check if already migrated
    if [[ "$FORCE" == "0" ]]; then
        local status
        status=$(remote_exec "$conn_type" "$conn_addr" "$REMOTE_USER" \
            "systemctl --user is-active hermes-gateway.service 2>/dev/null || echo inactive") || true
        if [[ "$status" == "active" ]]; then
            success "hermes-gateway already active on $host — skipping (--force to re-run)"
            return 0
        fi
    fi

    # Copy bootstrap script to target
    info "Uploading bootstrap-hermes.sh..."
    if [[ -f "$BOOTSTRAP_SCRIPT" ]]; then
        remote_scp "$conn_type" "$conn_addr" "$REMOTE_USER" \
            "$BOOTSTRAP_SCRIPT" "/tmp/bootstrap-hermes.sh"
    else
        # Fetch from GitHub directly on the target
        remote_exec "$conn_type" "$conn_addr" "$REMOTE_USER" \
            "curl -fsSL '$BOOTSTRAP_URL' -o /tmp/bootstrap-hermes.sh"
    fi
    remote_exec "$conn_type" "$conn_addr" "$REMOTE_USER" "chmod +x /tmp/bootstrap-hermes.sh"

    # Also push extract-openclaw-keys.py if present
    local extract_script="$SCRIPT_DIR/extract-openclaw-keys.py"
    if [[ -f "$extract_script" ]]; then
        remote_scp "$conn_type" "$conn_addr" "$REMOTE_USER" \
            "$extract_script" "/tmp/extract-openclaw-keys.py"
    fi

    # Build bootstrap flags
    local flags="--force"
    [[ -n "$EXTRA_ENV_CONTENT" ]] && flags+=" --env $(printf '%q' "$EXTRA_ENV_CONTENT")"

    # Run bootstrap on target
    info "Running bootstrap-hermes.sh on $host..."
    remote_exec "$conn_type" "$conn_addr" "$REMOTE_USER" \
        "bash /tmp/bootstrap-hermes.sh $flags" && \
        success "Migration complete: $host" || \
        { error "Migration failed: $host"; return 1; }
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}Hermes Swarm Migration${NC}"
echo -e "${CYAN}Orchestrator: $(hostname)${NC}"
echo -e "${CYAN}Targets (${#HOSTS[@]}): ${HOSTS[*]}${NC}"
echo ""

SUCCEEDED=()
FAILED=()
MANUAL=()

for host in "${HOSTS[@]}"; do
    if migrate_host "$host"; then
        SUCCEEDED+=("$host")
    else
        FAILED+=("$host")
        MANUAL+=("$host")
    fi
    echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
header "Summary"
echo ""

echo -e "  ${GREEN}Succeeded (${#SUCCEEDED[@]}):${NC}"
if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
    for h in "${SUCCEEDED[@]}"; do echo -e "    ${GREEN}✓${NC} $h"; done
else
    echo "    (none)"
fi

echo ""
echo -e "  ${RED}Failed (${#FAILED[@]}):${NC}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    for h in "${FAILED[@]}"; do echo -e "    ${RED}✗${NC} $h"; done
else
    echo "    (none)"
fi

if [[ ${#MANUAL[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}Manual bootstrap required:${NC}"
    echo -e "  ${YELLOW}Run this on each unreachable node (paste from phone):${NC}"
    echo ""
    echo -e "    curl -fsSL $BOOTSTRAP_URL | bash"
    echo ""
    for h in "${MANUAL[@]}"; do
        echo -e "    ${YELLOW}→${NC} $h"
    done
fi

echo ""
[[ ${#FAILED[@]} -eq 0 ]]
