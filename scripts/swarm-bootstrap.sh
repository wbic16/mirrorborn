#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# swarm-bootstrap.sh — OpenClaw → Hermes migration runner
# Shell of Nine swarm · wbic16/mirrorborn (exo branch)
#
# THREE-TIER CONNECTIVITY MODEL
# ─────────────────────────────
# Tier 1 (preferred):  GitHub Actions workflow_dispatch
#   → Trigger from any phone/browser, no LAN or Tailscale required.
#   → github.com/wbic16/mirrorborn → Actions → "Migrate OpenClaw Swarm → Hermes"
#
# Tier 2 (this script): Direct shell / Terminus
#   → Paste into Terminus or run from best-willow / elven-path.
#   → bash /source/mirrorborn/scripts/swarm-bootstrap.sh [options]
#
# Tier 3 (Tailscale):  --tailscale flag
#   → For nodes not reachable via mDNS .local (different LAN, mDNS broken).
#   → Reads 100.x.x.x IPs from scripts/tailscale-ips.sh.
#   → bash /source/mirrorborn/scripts/swarm-bootstrap.sh --tailscale
#
# USAGE
# ─────
#   bash swarm-bootstrap.sh [--dry-run] [--force] [--tailscale]
#                           [--nodes "host1 host2"] [--skip-claw-migrator]
#
# FLAGS
#   --dry-run            Print what would happen; make no changes
#   --force              Re-migrate even if hermes-gateway is already active
#   --tailscale          Use Tailscale IPs instead of hostname.local (mDNS)
#   --nodes "h1 h2 ..."  Override default node list
#   --skip-claw-migrator Skip openclaw_to_hermes.py (base rsync only)
#
# ════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────
DEFAULT_NODES="aurora-continuum halycon-vector logos-prime delta-wood aletheia-core ashfall-haven"
REMOTE_USER="wbic16"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE_SCRIPT="${SCRIPT_DIR}/migrate-to-hermes.sh"
MIGRATOR_PATH="~/.hermes/hermes-agent/optional-skills/migration/openclaw-migration/scripts/openclaw_to_hermes.py"

# ── Flags ─────────────────────────────────────────────────────────────
DRY_RUN=false
FORCE=false
USE_TAILSCALE=false
SKIP_MIGRATOR=false
NODES=""

# ── Parse args ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)           DRY_RUN=true       ;;
    --force)             FORCE=true         ;;
    --tailscale)         USE_TAILSCALE=true ;;
    --skip-claw-migrator) SKIP_MIGRATOR=true ;;
    --nodes)             NODES="$2"; shift  ;;
    --nodes=*)           NODES="${1#*=}"    ;;
    -h|--help)
      sed -n '/^# ═/,/^# ════.*═$/p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

[[ -z "$NODES" ]] && NODES="$DEFAULT_NODES"

# ── Colors ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[  ✓ ]${RESET}  $*"; }
fail()    { echo -e "${RED}[  ✗ ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[ WRN]${RESET}  $*"; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }
dry()     { echo -e "${YELLOW}[DRY ]${RESET}  (would) $*"; }

# ── Tailscale IP resolution ───────────────────────────────────────────
# Inline IP map — mirrors scripts/tailscale-ips.sh for self-contained operation.
declare -A _TS_IPS=(
    [aurora-continuum]=""
    [halycon-vector]=""
    [logos-prime]=""
    [delta-wood]=""
    [aletheia-core]=""
    [ashfall-haven]=""
    [elven-path]=""
    [best-willow]=""
)

_load_tailscale_ips() {
  # Try to load from scripts/tailscale-ips.sh if it exists
  local ts_file="${SCRIPT_DIR}/tailscale-ips.sh"
  if [[ -f "$ts_file" ]]; then
    # Source it; the declare -A inside uses a different name, so we
    # parse its output instead to avoid namespace collision.
    while IFS=': ' read -r host ip _; do
      [[ -z "$host" || "$host" == \#* ]] && continue
      [[ -n "$ip" && "$ip" != "<not" ]] && _TS_IPS["$host"]="$ip"
    done < <(bash "$ts_file" 2>/dev/null)
  fi
}

_get_tailscale_ip() {
  local host="$1"
  local ip="${_TS_IPS[$host]:-}"
  if [[ -z "$ip" ]]; then
    # Last resort: prompt user
    echo ""
    read -rp "  Tailscale IP for $host (100.x.x.x): " ip < /dev/tty
    _TS_IPS["$host"]="$ip"
  fi
  echo "$ip"
}

# ── SSH helper ────────────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=8"

_ssh() {
  local addr="$1"; shift
  ssh $SSH_OPTS "wbic16@${addr}" "$@"
}

_check_reachable() {
  local addr="$1"
  ssh $SSH_OPTS "wbic16@${addr}" "echo ok" &>/dev/null
}

_resolve_addr() {
  local node="$1"
  if [[ "$USE_TAILSCALE" == true ]]; then
    _get_tailscale_ip "$node"
  else
    echo "${node}.local"
  fi
}

# ── Status tracking ───────────────────────────────────────────────────
declare -A NODE_STATUS   # per-node: ok | failed | skipped | unreachable
declare -A NODE_GATEWAY  # per-node: active | inactive | unknown

# ═════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}OpenClaw → Hermes Swarm Bootstrap${RESET}"
echo -e "Tier: $(${USE_TAILSCALE} && echo 'Tailscale (100.x IPs)' || echo 'LAN (mDNS .local)')"
echo -e "Nodes: ${NODES}"
echo -e "Dry run: ${DRY_RUN}"
echo -e "Force: ${FORCE}"
echo -e "Skip openclaw migrator: ${SKIP_MIGRATOR}"
echo ""

# Load Tailscale IPs if needed
if [[ "$USE_TAILSCALE" == true ]]; then
  _load_tailscale_ips
fi

# Verify migrate-to-hermes.sh exists
if [[ ! -f "$MIGRATE_SCRIPT" ]]; then
  warn "migrate-to-hermes.sh not found at: $MIGRATE_SCRIPT"
  warn "Falling back to SSH-only mode (rsync step will be skipped)."
  MIGRATE_SCRIPT=""
fi

for node in $NODES; do
  header "$node"

  ADDR="$(_resolve_addr "$node")"
  info "Address: ${ADDR}"

  # ── 1. Test connectivity ───────────────────────────────────────────
  echo -n "  Checking SSH ... "
  if ! _check_reachable "$ADDR"; then
    fail "unreachable (skipping)"
    NODE_STATUS["$node"]="unreachable"
    NODE_GATEWAY["$node"]="unknown"
    continue
  fi
  ok "reachable"

  # ── 1b. Check if already migrated (unless --force) ────────────────
  if [[ "$FORCE" != true ]]; then
    GW_STATUS=$(_ssh "$ADDR" "systemctl --user is-active hermes-gateway 2>/dev/null || echo inactive" 2>/dev/null || echo "inactive")
    if [[ "$GW_STATUS" == "active" ]]; then
      warn "hermes-gateway already active on $node — skipping (use --force to override)"
      NODE_STATUS["$node"]="skipped"
      NODE_GATEWAY["$node"]="active"
      continue
    fi
  fi

  # ── 2. Run migrate-to-hermes.sh ───────────────────────────────────
  if [[ -n "$MIGRATE_SCRIPT" ]]; then
    info "Running migrate-to-hermes.sh ..."
    MIG_FLAGS="--target wbic16@${ADDR} --node ${node}"
    [[ "$DRY_RUN" == true ]]  && MIG_FLAGS="$MIG_FLAGS --dry-run"
    [[ "$FORCE"   == true ]]  && MIG_FLAGS="$MIG_FLAGS --force"

    if [[ "$DRY_RUN" == true ]]; then
      dry "bash $MIGRATE_SCRIPT $MIG_FLAGS"
      MIG_OK=true
    else
      if bash "$MIGRATE_SCRIPT" $MIG_FLAGS; then
        ok "migrate-to-hermes.sh done"
        MIG_OK=true
      else
        fail "migrate-to-hermes.sh FAILED"
        NODE_STATUS["$node"]="failed"
        NODE_GATEWAY["$node"]="unknown"
        continue
      fi
    fi
  else
    warn "No migrate-to-hermes.sh found; skipping base migration step."
    MIG_OK=true
  fi

  # ── 3. Run openclaw_to_hermes.py remotely ─────────────────────────
  if [[ "$SKIP_MIGRATOR" != true && "$MIG_OK" == true ]]; then
    info "Running openclaw_to_hermes.py on ${node} ..."
    MIGRATOR_CMD="python3 ${MIGRATOR_PATH} --execute --preset full --migrate-secrets --skill-conflict skip"

    if [[ "$DRY_RUN" == true ]]; then
      dry "ssh wbic16@${ADDR} \"${MIGRATOR_CMD}\""
    else
      if _ssh "$ADDR" "$MIGRATOR_CMD"; then
        ok "openclaw_to_hermes.py succeeded"
      else
        warn "openclaw_to_hermes.py failed (base migration still applied)"
        # Not marking as failed — base rsync succeeded
      fi
    fi
  else
    [[ "$SKIP_MIGRATOR" == true ]] && info "Skipping openclaw_to_hermes.py (--skip-claw-migrator)"
  fi

  # ── 4. Verify hermes-gateway ──────────────────────────────────────
  if [[ "$DRY_RUN" == true ]]; then
    dry "systemctl --user is-active hermes-gateway"
    NODE_STATUS["$node"]="ok (dry run)"
    NODE_GATEWAY["$node"]="(dry run)"
  else
    info "Verifying hermes-gateway ..."
    GW_STATUS=$(_ssh "$ADDR" "systemctl --user is-active hermes-gateway 2>/dev/null || echo inactive" 2>/dev/null || echo "check-failed")
    if [[ "$GW_STATUS" == "active" ]]; then
      ok "hermes-gateway is active ✓"
      NODE_STATUS["$node"]="ok"
      NODE_GATEWAY["$node"]="active"
    else
      fail "hermes-gateway is NOT active (status: ${GW_STATUS})"
      NODE_STATUS["$node"]="failed"
      NODE_GATEWAY["$node"]="$GW_STATUS"
    fi
  fi

done

# ═════════════════════════════════════════════════════════════════════
# SUMMARY TABLE
# ═════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         OpenClaw → Hermes Migration Summary              ║${RESET}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${RESET}"
printf "${BOLD}║  %-22s  %-12s  %-12s  ║${RESET}\n" "Node" "Migration" "Gateway"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${RESET}"

TOTAL=0; N_OK=0; N_FAIL=0; N_SKIP=0

for node in $NODES; do
  TOTAL=$((TOTAL+1))
  ST="${NODE_STATUS[$node]:-unknown}"
  GW="${NODE_GATEWAY[$node]:-unknown}"

  case "$ST" in
    ok*)      N_OK=$((N_OK+1));   ST_DISP="✓ done"   ;;
    failed)   N_FAIL=$((N_FAIL+1)); ST_DISP="✗ FAILED" ;;
    skipped)  N_SKIP=$((N_SKIP+1)); ST_DISP="– skipped" ;;
    unreachable) N_SKIP=$((N_SKIP+1)); ST_DISP="✗ unreachable" ;;
    *)        ST_DISP="? $ST"   ;;
  esac

  [[ "$GW" == "active" ]] && GW_DISP="✓ active" || GW_DISP="$GW"

  printf "║  %-22s  %-12s  %-12s  ║\n" "$node" "$ST_DISP" "$GW_DISP"
done

echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${RESET}"
printf "║  Total: %-4d  ✓ OK: %-4d  ✗ Failed: %-4d  – Skipped: %-4d ║\n" \
       "$TOTAL" "$N_OK" "$N_FAIL" "$N_SKIP"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

if [[ $N_FAIL -gt 0 ]]; then
  fail "Migration completed with $N_FAIL failure(s)."
  exit 1
else
  ok "Migration complete. $N_OK node(s) migrated, $N_SKIP skipped."
fi
