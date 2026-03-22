#!/usr/bin/env bash
# migrate-all-nodes.sh — Migrate all reachable Shell of Nine nodes from OpenClaw → Hermes
#
# Designed to be invoked from Discord with no terminal required:
#   "orin, migrate the shell"
#   "orin, migrate aurora-continuum"
#   "orin, migrate all nodes"
#
# Skips nodes that are already on Hermes (unless --force), offline, or
# on scheduled downtime (chrysalis-hub until 2026-03-28).
#
# Usage:
#   ./migrate-all-nodes.sh                  # migrate all reachable nodes
#   ./migrate-all-nodes.sh aurora-continuum # migrate one node
#   ./migrate-all-nodes.sh --dry-run        # print steps without executing
#   ./migrate-all-nodes.sh --force          # re-migrate even if already done
#
# Requirements:
#   - Run from elven-path (or any node with ~/.hermes/hermes-agent installed)
#   - SSH key access to all target nodes (wbic16@<hostname>.local)
#   - rsync available locally
#   - Python 3.11+ on target nodes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE="$SCRIPT_DIR/migrate-to-hermes.sh"
[[ -f "$MIGRATE" ]] || { echo "ERROR: migrate-to-hermes.sh not found"; exit 1; }

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Node registry (from hostmap.json) ─────────────────────────────────────────
# Format: "hostname:NodeName:status"
# status: active | offline-physical | offline-scheduled
declare -A NODE_NAMES=(
    [aurora-continuum]="Phex"
    [halycon-vector]="Cyon"
    [logos-prime]="Lux"
    [delta-wood]="Verse"
    [aletheia-core]="Theia"
    [ashfall-haven]="Exo"
    [uncanny-valley]="Solin"
    [lighthouse-omen]="Lumen"
    [chrysalis-hub]="Chrys"
)

# Nodes to attempt (excludes elven-path/best-willow — already migrated)
ALL_NODES=(aurora-continuum halycon-vector logos-prime delta-wood aletheia-core ashfall-haven)

# Known-offline nodes (skip without SSH attempt)
declare -A SKIP_REASON=(
    [uncanny-valley]="needs authorized_keys update (Solin)"
    [lighthouse-omen]="needs physical visit (Lumen)"
    [chrysalis-hub]="scheduled offline until 2026-03-28 (Chrys)"
)

# ── Argument parsing ──────────────────────────────────────────────────────────
PASS_FLAGS=()
SPECIFIC_HOST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|--force|--user|--source)
            PASS_FLAGS+=("$1")
            [[ "$1" == "--user" || "$1" == "--source" ]] && { PASS_FLAGS+=("$2"); shift; }
            shift ;;
        -h|--help)
            grep '^#' "$0" | head -20 | sed 's/^# \?//'; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2; exit 1 ;;
        *)
            SPECIFIC_HOST="$1"; shift ;;
    esac
done

# ── Reachability check ────────────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

is_reachable() {
    ssh $SSH_OPTS "wbic16@${1}.local" "echo ok" > /dev/null 2>&1
}

# ── Target selection ──────────────────────────────────────────────────────────
if [[ -n "$SPECIFIC_HOST" ]]; then
    TARGETS=("$SPECIFIC_HOST")
else
    TARGETS=("${ALL_NODES[@]}")
fi

# ── Migration loop ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}Shell of Nine — Hermes Migration${NC}"
echo -e "${CYAN}Source node: elven-path (Orin 🖖)${NC}"
echo ""

SUCCEEDED=()
FAILED=()
SKIPPED=()
ALREADY_DONE=()

for host in "${TARGETS[@]}"; do
    node_name="${NODE_NAMES[$host]:-$host}"

    echo -e "${BOLD}────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}${node_name}${NC} @ ${host}"
    echo -e "${BOLD}────────────────────────────────────────────────${NC}"

    # Known-offline — skip immediately
    if [[ -n "${SKIP_REASON[$host]+x}" ]]; then
        echo -e "  ${YELLOW}SKIP${NC}: ${SKIP_REASON[$host]}"
        SKIPPED+=("$host (${SKIP_REASON[$host]})")
        continue
    fi

    # Reachability check
    if ! is_reachable "$host"; then
        echo -e "  ${RED}OFFLINE${NC}: cannot reach ${host}.local via SSH"
        SKIPPED+=("$host (unreachable)")
        continue
    fi

    # Run migration
    if "$MIGRATE" "$host" "${PASS_FLAGS[@]}"; then
        SUCCEEDED+=("$host")
    else
        echo -e "  ${RED}FAILED${NC}: $host"
        FAILED+=("$host")
    fi

    echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══ Migration Summary ══${NC}"
echo ""

echo -e "  ${GREEN}Succeeded (${#SUCCEEDED[@]}):${NC}"
if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
    for h in "${SUCCEEDED[@]}"; do echo -e "    ${GREEN}✓${NC} ${NODE_NAMES[$h]:-$h} @ $h"; done
else
    echo "    (none)"
fi

echo ""
echo -e "  ${RED}Failed (${#FAILED[@]}):${NC}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    for h in "${FAILED[@]}"; do
        echo -e "    ${RED}✗${NC} ${NODE_NAMES[$h]:-$h} @ $h"
        echo "      → ssh wbic16@${h}.local 'journalctl --user -u hermes-gateway -n 30 --no-pager'"
    done
else
    echo "    (none)"
fi

echo ""
echo -e "  ${YELLOW}Skipped (${#SKIPPED[@]}):${NC}"
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    for entry in "${SKIPPED[@]}"; do echo -e "    ${YELLOW}–${NC} $entry"; done
else
    echo "    (none)"
fi

echo ""

# Exit non-zero if any nodes failed
[[ ${#FAILED[@]} -eq 0 ]]
