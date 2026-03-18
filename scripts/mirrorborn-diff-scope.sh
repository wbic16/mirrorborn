#!/bin/bash
# mirrorborn-diff-scope — categorize what changed in a diff
# Adapted from garrytan/gstack gstack-diff-scope (MIT, v0.6.3)
# Extended with SCOPE_PHEXT and SCOPE_MESH for Mirrorborn-specific routing
#
# Usage: eval $(bash mirrorborn-diff-scope.sh <base_branch>)
# Sets: SCOPE_FRONTEND SCOPE_BACKEND SCOPE_PROMPTS SCOPE_TESTS
#       SCOPE_DOCS SCOPE_CONFIG SCOPE_PHEXT SCOPE_MESH
#
# FORGE routing:
#   SCOPE_FRONTEND  → Exo (design review) + Chrys (copy review)
#   SCOPE_BACKEND   → Phex (code review)
#   SCOPE_PROMPTS   → Solin (mission alignment review)
#   SCOPE_TESTS     → Exo (QA sweep)
#   SCOPE_DOCS      → check coordinate drift + attribution
#   SCOPE_CONFIG    → Verse (infrastructure impact)
#   SCOPE_PHEXT     → lattice integrity check (coordinate drift)
#   SCOPE_MESH      → Verse (boot/mesh config review)
set -euo pipefail

BASE="${1:-main}"

FILES=$(git diff "${BASE}...HEAD" --name-only 2>/dev/null || \
        git diff "${BASE}" --name-only 2>/dev/null || \
        echo "")

if [ -z "$FILES" ]; then
  echo "SCOPE_FRONTEND=false"
  echo "SCOPE_BACKEND=false"
  echo "SCOPE_PROMPTS=false"
  echo "SCOPE_TESTS=false"
  echo "SCOPE_DOCS=false"
  echo "SCOPE_CONFIG=false"
  echo "SCOPE_PHEXT=false"
  echo "SCOPE_MESH=false"
  exit 0
fi

FRONTEND=false
BACKEND=false
PROMPTS=false
TESTS=false
DOCS=false
CONFIG=false
PHEXT=false
MESH=false

while IFS= read -r f; do
  case "$f" in
    # ── Frontend (same as gstack-diff-scope, stripped Rails paths) ──────────
    *.css|*.scss|*.less|*.sass|*.pcss|*.module.css|*.module.scss) FRONTEND=true ;;
    *.tsx|*.jsx|*.vue|*.svelte|*.astro) FRONTEND=true ;;
    *.html) FRONTEND=true ;;
    tailwind.config.*|postcss.config.*) FRONTEND=true ;;
    */components/*|styles/*|css/*) FRONTEND=true ;;

    # ── Prompts: skill files, role configs, system prompts ─────────────────
    skills/*|*/SKILL.md|*/SOUL.md|*/IDENTITY.md) PROMPTS=true ;;
    */system_prompts/*|*prompt*) PROMPTS=true ;;
    styles/*.md) PROMPTS=true ;;  # Coding style guides affect prompt behavior

    # ── Tests ────────────────────────────────────────────────────────────────
    *.test.*|*.spec.*|*_test.*|*_spec.*) TESTS=true ;;
    tests/*|test/*|benchmarks/*) TESTS=true ;;

    # ── Docs ─────────────────────────────────────────────────────────────────
    *.md) DOCS=true ;;

    # ── Config: Rust, Python, Node, general ──────────────────────────────────
    Cargo.toml|Cargo.lock) CONFIG=true ;;
    requirements.txt|pyproject.toml|setup.py) CONFIG=true ;;
    package.json|package-lock.json|yarn.lock|bun.lockb) CONFIG=true ;;
    *.yml|*.yaml|*.json) CONFIG=true ;;
    .github/*) CONFIG=true ;;

    # ── Phext: coordinate changes, phext files, lattice structure ────────────
    *.phext) PHEXT=true ;;
    *coordinate*|*coord*|*PhextCoord*|*phext_coord*) PHEXT=true ;;
    src/coord/*|*/coord.rs|*/phext.rs) PHEXT=true ;;
    human.phext|*.phext|specs/*.md) PHEXT=true ;;

    # ── Mesh: boot/infrastructure/node config ────────────────────────────────
    boot.sh|hostmap.json) MESH=true ;;
    openclaw.json|*/openclaw.json) MESH=true ;;
    scripts/uptime*|scripts/dashboard*|scripts/mesh*|scripts/orchestrate*) MESH=true ;;
    scripts/daily-report*|scripts/cadence*|scripts/retro*) MESH=true ;;
    /etc/mirrorborn/*|mirrorborn.service) MESH=true ;;

    # ── Backend: Rust, Python, Go, bash scripts ───────────────────────────────
    *.rs|*.py|*.go|*.sh|*.bash) BACKEND=true ;;
    *.ts|*.js) BACKEND=true ;;
  esac
done <<< "$FILES"

echo "SCOPE_FRONTEND=$FRONTEND"
echo "SCOPE_BACKEND=$BACKEND"
echo "SCOPE_PROMPTS=$PROMPTS"
echo "SCOPE_TESTS=$TESTS"
echo "SCOPE_DOCS=$DOCS"
echo "SCOPE_CONFIG=$CONFIG"
echo "SCOPE_PHEXT=$PHEXT"
echo "SCOPE_MESH=$MESH"

# Summary for humans
>&2 echo "Scopes: $(
  scopes=""
  [ "$FRONTEND" = "true" ] && scopes="${scopes}FRONTEND(→Exo+Chrys) "
  [ "$BACKEND"  = "true" ] && scopes="${scopes}BACKEND(→Phex) "
  [ "$PROMPTS"  = "true" ] && scopes="${scopes}PROMPTS(→Solin) "
  [ "$TESTS"    = "true" ] && scopes="${scopes}TESTS(→Exo) "
  [ "$MESH"     = "true" ] && scopes="${scopes}MESH(→Verse) "
  [ "$PHEXT"    = "true" ] && scopes="${scopes}PHEXT(→lattice-check) "
  [ "$DOCS"     = "true" ] && scopes="${scopes}DOCS "
  [ "$CONFIG"   = "true" ] && scopes="${scopes}CONFIG "
  echo ${scopes:-none}
)"
