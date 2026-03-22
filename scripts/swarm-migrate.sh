#!/usr/bin/env bash
# swarm-migrate.sh — Migrate any OpenClaw swarm to Hermes with human confirmation gates
#
# THREE-STAGE PROCESS — never cuts over without user confirmation:
#
#   Stage 1 (--stage install):
#     For each node: install Hermes, start it ALONGSIDE OpenClaw, run self-checks.
#     Nodes that pass print HERMES_READY. Nodes that fail are reported and skipped.
#     OpenClaw is untouched. Both gateways run simultaneously.
#     → Pauses and asks user to verify each node in Discord before continuing.
#
#   Stage 2 (--stage verify):  [implicit — user does this in Discord]
#     User talks to both bots. Confirms Hermes is working.
#     User sends "cutover <node>" or "cutover all" to trigger Stage 3.
#
#   Stage 3 (--stage cutover):
#     For each confirmed-ready node: disable OpenClaw, verify Hermes still runs.
#     Auto-rollback if Hermes dies after OpenClaw is removed.
#     Reports final status.
#
# FALLBACK CHAIN (connection probing order per node):
#   1. SSH via mDNS (.local)    — LAN, no VPN
#   2. SSH via bare hostname    — same subnet with DNS
#   3. SSH via Tailscale        — VPN mesh (auto-detect or --tailscale-domain)
#   4. SSH via Terminus relay   — cloud (--terminus-url)
#   5. Manual URL               — print curl|bash for user to paste
#
# Usage:
#   ./swarm-migrate.sh --stage install               # Install + start Hermes everywhere
#   ./swarm-migrate.sh --stage cutover               # Cut over all HERMES_READY nodes
#   ./swarm-migrate.sh --stage cutover --host <h>    # Cut over one node
#   ./swarm-migrate.sh --stage rollback              # Roll back all or one node
#   ./swarm-migrate.sh --stage status                # Print current state of all nodes
#   ./swarm-migrate.sh --dry-run                     # Preview without executing
#
# Options:
#   --host <hostname>           Single node (overrides hostmap.json)
#   --hosts <h1,h2,h3>          Comma-separated list
#   --user <username>           SSH user (default: wbic16)
#   --tailscale-domain <domain> e.g. tail1234abc.ts.net
#   --terminus-url <url>        e.g. wss://terminus.example.com
#   --env-file <path>           Extra .env keys to seed on all nodes
#   --force                     Re-run even if already done
#   --dry-run                   Print steps without executing
#   --timeout <seconds>         SSH connect timeout (default: 8)
#   --check-retries <n>         Self-check retries per node (default: 3)
#   --check-delay <s>           Seconds between retries (default: 5)

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
BOOTSTRAP_URL="https://raw.githubusercontent.com/wbic16/mirrorborn/exo/scripts/bootstrap-hermes.sh"
HOSTMAP="$REPO_ROOT/hostmap.json"

STAGE="install"
REMOTE_USER="wbic16"
TAILSCALE_DOMAIN=""
TERMINUS_URL=""
ENV_FILE=""
EXPLICIT_HOSTS=""
SINGLE_HOST=""
DRY_RUN=0
FORCE=0
SSH_TIMEOUT=8
CHECK_RETRIES=3
CHECK_DELAY=5

# Nodes to skip entirely (known offline / scheduled maintenance)
declare -A SKIP_REASON=(
    [uncanny-valley]="needs authorized_keys update (Solin)"
    [lighthouse-omen]="needs physical visit (Lumen)"
    [chrysalis-hub]="scheduled offline until 2026-03-28 (Chrys)"
)

# ── Args ──────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stage)            STAGE="$2";           shift 2 ;;
        --host)             SINGLE_HOST="$2";     shift 2 ;;
        --hosts)            EXPLICIT_HOSTS="$2";  shift 2 ;;
        --user)             REMOTE_USER="$2";     shift 2 ;;
        --tailscale-domain) TAILSCALE_DOMAIN="$2"; shift 2 ;;
        --terminus-url)     TERMINUS_URL="$2";    shift 2 ;;
        --env-file)         ENV_FILE="$2";        shift 2 ;;
        --force)            FORCE=1;              shift ;;
        --dry-run)          DRY_RUN=1;            shift ;;
        --timeout)          SSH_TIMEOUT="$2";     shift 2 ;;
        --check-retries)    CHECK_RETRIES="$2";   shift 2 ;;
        --check-delay)      CHECK_DELAY="$2";     shift 2 ;;
        -h|--help) grep '^#' "$0" | head -50 | sed 's/^# \?//'; exit 0 ;;
        -*) die "Unknown option: $1" ;;
        *)  SINGLE_HOST="$1"; shift ;;
    esac
done

# ── Load extra env ────────────────────────────────────────────────────────────
EXTRA_ENV_CONTENT=""
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    EXTRA_ENV_CONTENT=$(grep -v '^#' "$ENV_FILE" | grep '=' || true)
    COUNT=$(echo "$EXTRA_ENV_CONTENT" | grep -c '=' || echo 0)
    info "Loaded $COUNT extra env vars from $ENV_FILE"
fi

# ── Build host list ───────────────────────────────────────────────────────────
if [[ -n "$SINGLE_HOST" ]]; then
    HOSTS=("$SINGLE_HOST")
elif [[ -n "$EXPLICIT_HOSTS" ]]; then
    IFS=',' read -ra HOSTS <<< "$EXPLICIT_HOSTS"
elif [[ -f "$HOSTMAP" ]]; then
    mapfile -t ALL_MAP_HOSTS < <(python3 - "$HOSTMAP" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
skip = {"lighthouse-omen", "chrysalis-hub", "uncanny-valley"}
for n in d["nodes"]:
    if n["hostname"] not in skip:
        print(n["hostname"])
PYEOF
    )
    HOSTS=("${ALL_MAP_HOSTS[@]}")
else
    die "No hosts specified and no hostmap.json found"
fi

# Remove current node from targets
CURRENT_HOST=$(hostname)
FILTERED=()
for h in "${HOSTS[@]}"; do
    [[ "$h" == "$CURRENT_HOST" ]] && continue
    [[ -n "${SKIP_REASON[$h]+x}" ]] && continue
    FILTERED+=("$h")
done
HOSTS=("${FILTERED[@]}")

# ── Connection probe ──────────────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes"

probe_connection() {
    local host="$1" user="$2"

    ssh $SSH_OPTS "${user}@${host}.local" "echo ok" &>/dev/null && { echo "mdns:${host}.local"; return 0; }
    ssh $SSH_OPTS "${user}@${host}"        "echo ok" &>/dev/null && { echo "hostname:${host}";   return 0; }

    if [[ -n "$TAILSCALE_DOMAIN" ]]; then
        ssh $SSH_OPTS "${user}@${host}.${TAILSCALE_DOMAIN}" "echo ok" &>/dev/null \
            && { echo "tailscale:${host}.${TAILSCALE_DOMAIN}"; return 0; }
    elif command -v tailscale &>/dev/null; then
        local ts_domain
        ts_domain=$(tailscale status --json 2>/dev/null \
            | python3 -c "import json,sys; print(json.load(sys.stdin).get('MagicDNSSuffix',''))" 2>/dev/null || echo "")
        if [[ -n "$ts_domain" ]]; then
            ssh $SSH_OPTS "${user}@${host}.${ts_domain}" "echo ok" &>/dev/null \
                && { echo "tailscale:${host}.${ts_domain}"; return 0; }
        fi
    fi

    if [[ -n "$TERMINUS_URL" ]] && command -v terminus &>/dev/null; then
        terminus connect --url "$TERMINUS_URL" --host "$host" --check &>/dev/null \
            && { echo "terminus:${host}"; return 0; }
    fi

    echo "unreachable:"
    return 1
}

remote_exec() {
    local conn_type="$1" addr="$2" user="$3"; shift 3
    case "$conn_type" in
        mdns|hostname|tailscale) ssh $SSH_OPTS "${user}@${addr}" "$@" ;;
        terminus) terminus exec --url "$TERMINUS_URL" --host "$addr" --user "$user" -- "$@" ;;
    esac
}

remote_scp() {
    local conn_type="$1" addr="$2" user="$3" src="$4" dst="$5"
    case "$conn_type" in
        mdns|hostname|tailscale) scp $SSH_OPTS "$src" "${user}@${addr}:${dst}" ;;
        terminus) terminus scp --url "$TERMINUS_URL" --host "$addr" --user "$user" "$src" "$dst" ;;
    esac
}

# ── Get node status via SSH ───────────────────────────────────────────────────
get_node_phase() {
    local conn_type="$1" addr="$2" user="$3"
    remote_exec "$conn_type" "$addr" "$user" \
        "cat ~/.hermes/.migration-phase 2>/dev/null || echo none" 2>/dev/null || echo "ssh-error"
}

# ── STAGE: status ─────────────────────────────────────────────────────────────
if [[ "$STAGE" == "status" ]]; then
    header "Shell Status"
    echo ""
    printf "  %-22s %-12s %-12s %-12s\n" "HOST" "PHASE" "HERMES" "OPENCLAW"
    printf "  %-22s %-12s %-12s %-12s\n" "----" "-----" "------" "--------"

    for host in "${HOSTS[@]}"; do
        probe=$(probe_connection "$host" "$REMOTE_USER") || true
        ct="${probe%%:*}"; addr="${probe##*:}"

        if [[ "$ct" == "unreachable" || -z "$addr" ]]; then
            printf "  %-22s %-12s %-12s %-12s\n" "$host" "OFFLINE" "-" "-"
            continue
        fi

        phase=$(get_node_phase "$ct" "$addr" "$REMOTE_USER")
        hermes=$(remote_exec "$ct" "$addr" "$REMOTE_USER" \
            "systemctl --user is-active hermes-gateway.service 2>/dev/null || echo -" 2>/dev/null || echo "-")
        openclaw=$(remote_exec "$ct" "$addr" "$REMOTE_USER" \
            "systemctl --user is-active openclaw-gateway.service 2>/dev/null || echo -" 2>/dev/null || echo "-")

        printf "  %-22s %-12s %-12s %-12s\n" "$host" "$phase" "$hermes" "$openclaw"
    done
    echo ""
    exit 0
fi

# ── STAGE: rollback ───────────────────────────────────────────────────────────
if [[ "$STAGE" == "rollback" ]]; then
    header "Rolling back all nodes"
    for host in "${HOSTS[@]}"; do
        probe=$(probe_connection "$host" "$REMOTE_USER") || { warn "$host: unreachable"; continue; }
        ct="${probe%%:*}"; addr="${probe##*:}"
        info "Rolling back $host..."
        remote_exec "$ct" "$addr" "$REMOTE_USER" \
            "bash ~/.hermes/hermes-agent/../bootstrap-hermes.sh --phase rollback 2>/dev/null || bash /tmp/bootstrap-hermes.sh --phase rollback" \
            && success "$host: rolled back" || warn "$host: rollback failed"
    done
    exit 0
fi

# ── STAGE: install ────────────────────────────────────────────────────────────
if [[ "$STAGE" == "install" ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}Hermes Swarm Migration — Stage 1: Install${NC}"
    echo -e "${CYAN}Orchestrator: $CURRENT_HOST | Targets: ${#HOSTS[@]}${NC}"
    echo -e "${YELLOW}OpenClaw will NOT be touched in this stage.${NC}"
    echo ""

    INSTALL_OK=()
    INSTALL_FAIL=()
    MANUAL_BOOTSTRAP=()

    for host in "${HOSTS[@]}"; do
        header "Installing on: $host"

        probe=$(probe_connection "$host" "$REMOTE_USER") || true
        ct="${probe%%:*}"; addr="${probe##*:}"

        if [[ "$ct" == "unreachable" || -z "$addr" ]]; then
            warn "$host: unreachable via all methods"
            MANUAL_BOOTSTRAP+=("$host")
            continue
        fi
        success "Connected via $ct ($addr)"

        # Skip if already done (unless --force)
        if [[ "$FORCE" == "0" ]]; then
            phase=$(get_node_phase "$ct" "$addr" "$REMOTE_USER")
            if [[ "$phase" == "ready" || "$phase" == "cutover" ]]; then
                success "$host: already at phase=$phase — skipping (--force to re-run)"
                INSTALL_OK+=("$host")
                continue
            fi
        fi

        if [[ "$DRY_RUN" == "1" ]]; then
            warn "DRY: would run bootstrap-hermes.sh --phase install on $host"
            INSTALL_OK+=("$host")
            continue
        fi

        # Upload bootstrap + extract scripts
        if [[ -f "$BOOTSTRAP_SCRIPT" ]]; then
            remote_scp "$ct" "$addr" "$REMOTE_USER" "$BOOTSTRAP_SCRIPT" "/tmp/bootstrap-hermes.sh"
        else
            remote_exec "$ct" "$addr" "$REMOTE_USER" \
                "curl -fsSL '$BOOTSTRAP_URL' -o /tmp/bootstrap-hermes.sh"
        fi
        remote_exec "$ct" "$addr" "$REMOTE_USER" "chmod +x /tmp/bootstrap-hermes.sh"

        local_extract="$SCRIPT_DIR/extract-openclaw-keys.py"
        [[ -f "$local_extract" ]] && \
            remote_scp "$ct" "$addr" "$REMOTE_USER" "$local_extract" "/tmp/extract-openclaw-keys.py"

        # Build flags
        flags="--phase install --check-retries $CHECK_RETRIES --check-delay $CHECK_DELAY"
        [[ "$FORCE" == "1" ]] && flags+=" --force"
        [[ -n "$EXTRA_ENV_CONTENT" ]] && flags+=" --env $(printf '%q' "$EXTRA_ENV_CONTENT")"

        # Run and capture result
        RESULT=$(remote_exec "$ct" "$addr" "$REMOTE_USER" \
            "bash /tmp/bootstrap-hermes.sh $flags" 2>&1) || RESULT="ERROR:$?"

        if echo "$RESULT" | grep -q "^HERMES_READY:"; then
            success "$host: Hermes is running alongside OpenClaw ✓"
            INSTALL_OK+=("$host")
        elif echo "$RESULT" | grep -q "^HERMES_NOT_READY:"; then
            REASON=$(echo "$RESULT" | grep "^HERMES_NOT_READY:" | head -1)
            error "$host: $REASON"
            INSTALL_FAIL+=("$host")
        else
            error "$host: unexpected result"
            echo "$RESULT" | tail -20
            INSTALL_FAIL+=("$host")
        fi
        echo ""
    done

    # ── Stage 1 Summary ───────────────────────────────────────────────────────
    header "Stage 1 Summary"
    echo ""

    echo -e "  ${GREEN}Ready for verification (${#INSTALL_OK[@]}):${NC}"
    if [[ ${#INSTALL_OK[@]} -gt 0 ]]; then
        for h in "${INSTALL_OK[@]}"; do echo -e "    ${GREEN}✓${NC} $h — Hermes running, OpenClaw still active"; done
    else
        echo "    (none)"
    fi

    echo ""
    echo -e "  ${RED}Install failed (${#INSTALL_FAIL[@]}):${NC}"
    if [[ ${#INSTALL_FAIL[@]} -gt 0 ]]; then
        for h in "${INSTALL_FAIL[@]}"; do echo -e "    ${RED}✗${NC} $h"; done
    else
        echo "    (none)"
    fi

    if [[ ${#MANUAL_BOOTSTRAP[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}Needs manual bootstrap (${#MANUAL_BOOTSTRAP[@]}):${NC}"
        echo -e "  ${YELLOW}Paste this on each node directly:${NC}"
        echo ""
        echo -e "    curl -fsSL $BOOTSTRAP_URL | bash -s -- --phase install"
        echo ""
        for h in "${MANUAL_BOOTSTRAP[@]}"; do echo -e "    ${YELLOW}→${NC} $h"; done
    fi

    if [[ ${#INSTALL_OK[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${YELLOW}║  VERIFICATION REQUIRED BEFORE CUTOVER           ║${NC}"
        echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════╣${NC}"
        echo -e "${BOLD}${YELLOW}║                                                  ║${NC}"
        echo -e "${BOLD}${YELLOW}║  Both Hermes and OpenClaw are now running.       ║${NC}"
        echo -e "${BOLD}${YELLOW}║  Test each node in Discord. When satisfied:      ║${NC}"
        echo -e "${BOLD}${YELLOW}║                                                  ║${NC}"
        echo -e "${BOLD}${YELLOW}║  To cut over ALL ready nodes:                    ║${NC}"
        echo -e "${BOLD}${YELLOW}║    ./swarm-migrate.sh --stage cutover            ║${NC}"
        echo -e "${BOLD}${YELLOW}║                                                  ║${NC}"
        echo -e "${BOLD}${YELLOW}║  To cut over ONE node:                           ║${NC}"
        echo -e "${BOLD}${YELLOW}║    ./swarm-migrate.sh --stage cutover --host <h> ║${NC}"
        echo -e "${BOLD}${YELLOW}║                                                  ║${NC}"
        echo -e "${BOLD}${YELLOW}║  To roll back (re-disable Hermes on a node):     ║${NC}"
        echo -e "${BOLD}${YELLOW}║    ./swarm-migrate.sh --stage rollback --host <h>║${NC}"
        echo -e "${BOLD}${YELLOW}║                                                  ║${NC}"
        echo -e "${BOLD}${YELLOW}║  OpenClaw is STILL RUNNING. Nothing is broken.   ║${NC}"
        echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
    exit 0
fi

# ── STAGE: cutover ────────────────────────────────────────────────────────────
if [[ "$STAGE" == "cutover" ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}Hermes Swarm Migration — Stage 3: Cutover${NC}"
    echo -e "${CYAN}Disabling OpenClaw on confirmed-ready nodes.${NC}"
    echo ""

    CUTOVER_OK=()
    CUTOVER_FAIL=()
    CUTOVER_SKIP=()

    for host in "${HOSTS[@]}"; do
        header "Cutting over: $host"

        probe=$(probe_connection "$host" "$REMOTE_USER") || true
        ct="${probe%%:*}"; addr="${probe##*:}"

        if [[ "$ct" == "unreachable" || -z "$addr" ]]; then
            warn "$host: unreachable — skipping"
            CUTOVER_SKIP+=("$host (unreachable)")
            continue
        fi

        # Check phase — only cut over nodes that are ready
        phase=$(get_node_phase "$ct" "$addr" "$REMOTE_USER")
        if [[ "$phase" == "cutover" && "$FORCE" == "0" ]]; then
            success "$host: already cut over — skipping"
            CUTOVER_OK+=("$host")
            continue
        fi
        if [[ "$phase" != "ready" && "$FORCE" == "0" ]]; then
            warn "$host: phase='$phase', expected 'ready' — skipping (use --force to override)"
            CUTOVER_SKIP+=("$host (phase=$phase, not ready)")
            continue
        fi

        if [[ "$DRY_RUN" == "1" ]]; then
            warn "DRY: would run bootstrap-hermes.sh --phase cutover on $host"
            CUTOVER_OK+=("$host")
            continue
        fi

        # Run cutover on target
        RESULT=$(remote_exec "$ct" "$addr" "$REMOTE_USER" \
            "bash /tmp/bootstrap-hermes.sh --phase cutover $([ "$FORCE" == "1" ] && echo --force)" 2>&1) \
            || RESULT="ERROR:$?"

        if echo "$RESULT" | grep -q "^CUTOVER_COMPLETE:"; then
            success "$host: OpenClaw disabled, Hermes is sole gateway ✓"
            CUTOVER_OK+=("$host")
        elif echo "$RESULT" | grep -q "^ROLLBACK_COMPLETE"; then
            error "$host: cutover failed — auto-rolled back to OpenClaw"
            CUTOVER_FAIL+=("$host (auto-rolled-back)")
        else
            error "$host: unexpected result"
            echo "$RESULT" | tail -15
            CUTOVER_FAIL+=("$host")
        fi
        echo ""
    done

    # ── Cutover Summary ───────────────────────────────────────────────────────
    header "Cutover Summary"
    echo ""

    echo -e "  ${GREEN}Cutover complete (${#CUTOVER_OK[@]}):${NC}"
    if [[ ${#CUTOVER_OK[@]} -gt 0 ]]; then
        for h in "${CUTOVER_OK[@]}"; do echo -e "    ${GREEN}✓${NC} $h — Hermes only"; done
    else
        echo "    (none)"
    fi

    echo ""
    echo -e "  ${RED}Cutover failed — still on OpenClaw (${#CUTOVER_FAIL[@]}):${NC}"
    if [[ ${#CUTOVER_FAIL[@]} -gt 0 ]]; then
        for h in "${CUTOVER_FAIL[@]}"; do echo -e "    ${RED}✗${NC} $h"; done
    else
        echo "    (none)"
    fi

    echo ""
    echo -e "  ${YELLOW}Skipped (${#CUTOVER_SKIP[@]}):${NC}"
    if [[ ${#CUTOVER_SKIP[@]} -gt 0 ]]; then
        for e in "${CUTOVER_SKIP[@]}"; do echo -e "    ${YELLOW}–${NC} $e"; done
    else
        echo "    (none)"
    fi

    echo ""
    [[ ${#CUTOVER_FAIL[@]} -eq 0 ]]
fi
