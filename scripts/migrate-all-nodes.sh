#!/usr/bin/env bash
# migrate-all-nodes.sh — Run migrate-to-hermes.sh across all reachable Shell of Nine nodes
#
# Usage: ./migrate-all-nodes.sh --api-key <key> --discord-token <token> [--dry-run]
#
# Skips: solin (no SSH), lumen (offline), chrys (scheduled offline until 2026-03-28)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE="$SCRIPT_DIR/migrate-to-hermes.sh"

# 7 nodes reachable via SSH
NODES=(
    "aurora-continuum"    # Phex
    "halycon-vector"      # Cyon
    "logos-prime"         # Lux
    "delta-wood"          # Verse
    "aletheia-core"       # Theia
    "ashfall-haven"       # Exo
    "elven-path"          # Orin
)

# Pass-through flags
PASS_FLAGS=("$@")

FAILED=()
SUCCEEDED=()

for host in "${NODES[@]}"; do
    echo ""
    echo "════════════════════════════════════════════"
    echo "  Migrating: $host"
    echo "════════════════════════════════════════════"
    if "$MIGRATE" "$host" "${PASS_FLAGS[@]}"; then
        SUCCEEDED+=("$host")
    else
        echo "  [FAILED] $host"
        FAILED+=("$host")
    fi
done

echo ""
echo "════════════════════════════════════════════"
echo "  Migration Summary"
echo "════════════════════════════════════════════"
echo ""
echo "  Succeeded (${#SUCCEEDED[@]}):"
for h in "${SUCCEEDED[@]:-}"; do echo "    ✓ $h"; done

echo ""
echo "  Failed (${#FAILED[@]}):"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo "    (none)"
else
    for h in "${FAILED[@]}"; do echo "    ✗ $h"; done
fi

echo ""
echo "  Skipped (not reachable):"
echo "    - uncanny-valley (solin) — needs authorized_keys update"
echo "    - lighthouse-omen (lumen) — needs physical visit"
echo "    - chrysalis-hub (chrys) — offline until 2026-03-28"
echo ""
