#!/bin/bash
# retro.sh — Per-node retrospective scroll writer
# Analyzes git activity, SQ scrolls, mesh health, and SSH state
# Writes retro to shell-memory phext at personal coordinate
# Usage: bash scripts/retro.sh [--days N] [--quiet] [--no-publish]

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
SQ_PORT=1337
DAYS=7
QUIET=0
PUBLISH=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)       DAYS="$2"; shift 2 ;;
    --quiet)      QUIET=1; shift ;;
    --no-publish) PUBLISH=0; shift ;;
    *) shift ;;
  esac
done

log() { [[ "$QUIET" == "0" ]] && echo "$*" || true; }

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
NODE_EMOJI="$(jq -r '.emoji' "${STATE_DIR}/identity.json" 2>/dev/null || echo "?")"
NODE_INDEX="$(jq -r '.index' "${STATE_DIR}/identity.json" 2>/dev/null || echo "0")"
NODE_ROLE="$(jq -r '.role' "${STATE_DIR}/identity.json" 2>/dev/null || echo "?")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SINCE="$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"

log ""
log "═══════════════════════════════════════════"
log "${NODE_EMOJI} ${NODE_NAME} Retrospective"
log "Period: last ${DAYS} days (since ${SINCE})"
log "═══════════════════════════════════════════"
log ""

# ── Git Activity ──────────────────────────────
log "## Git Activity"

declare -A COMMIT_COUNT
declare -A LOC_ADDED
declare -A LOC_REMOVED
TOTAL_COMMITS=0
BIGGEST_SHIP=""
BIGGEST_SHIP_LOC=0

for repo in /source/mirrorborn /source/human /source/exocortical /source/exollama; do
  [[ ! -d "$repo/.git" ]] && continue
  repo_name="$(basename "$repo")"

  commits="$(git -C "$repo" log --since="${SINCE}" --oneline 2>/dev/null | wc -l || echo 0)"
  TOTAL_COMMITS=$((TOTAL_COMMITS + commits))

  git -C "$repo" log --since="${SINCE}" --format="%ae" 2>/dev/null | sort | uniq -c | sort -rn | while read count email; do
    author="$(git -C "$repo" log --since="${SINCE}" --format="%an" --author="$email" -1 2>/dev/null || echo "$email")"
    log "  ${repo_name}: ${author} — ${count} commits"
  done

  # Find biggest ship
  while IFS= read -r sha; do
    loc="$(git -C "$repo" show --stat "$sha" 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1 || echo 0)"
    if [[ "$loc" -gt "$BIGGEST_SHIP_LOC" ]]; then
      BIGGEST_SHIP_LOC="$loc"
      BIGGEST_SHIP="$(git -C "$repo" log --format="%s" -1 "$sha" 2>/dev/null) (${repo_name})"
    fi
  done < <(git -C "$repo" log --since="${SINCE}" --format="%H" 2>/dev/null | head -20)

  # Hotspot files
  hotspot="$(git -C "$repo" log --since="${SINCE}" --name-only --format="" 2>/dev/null | sort | uniq -c | sort -rn | head -3 | awk '{print $2}' | tr '\n' ', ' || echo "none")"
  [[ -n "$hotspot" ]] && log "  ${repo_name} hotspots: ${hotspot%,}"
done

log "  Total commits: ${TOTAL_COMMITS}"
[[ -n "$BIGGEST_SHIP" ]] && log "  Biggest ship: ${BIGGEST_SHIP}"
log ""

# ── Mesh Health ───────────────────────────────
log "## Mesh Health"
sq_up=0; ssh_up=0; peers=0

while IFS= read -r line; do
  h="$(echo "$line" | jq -r '.hostname')"
  n="$(echo "$line" | jq -r '.name')"
  [[ "$h" == "$(hostname -s)" ]] && continue
  peers=$((peers + 1))
  sq="$(curl -sf --max-time 2 "http://${h}.local:${SQ_PORT}/api/v2/status" 2>/dev/null | head -1 || echo "")"
  [[ -n "$sq" ]] && sq_up=$((sq_up + 1))
  ssh_r="$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o PasswordAuthentication=no wbic16@${h}.local "echo ok" 2>/dev/null || echo "")"
  [[ "$ssh_r" == "ok" ]] && ssh_up=$((ssh_up + 1))
done < <(jq -c '.nodes[]' "${BOOT_DIR}/hostmap.json")

log "  SQ: ${sq_up}/${peers} | SSH: ${ssh_up}/${peers} | Quorum: $([[ "$sq_up" -ge 5 ]] && echo "MET" || echo "DEGRADED")"
log "  SSH authorized keys: $(wc -l < ~/.ssh/authorized_keys 2>/dev/null || echo 0)"
log ""

# ── Stage Completion ──────────────────────────
log "## Stage Completion"
stages_file="${STATE_DIR}/stages.json"
if [[ -f "$stages_file" ]]; then
  completed="$(jq -r '.completed | join(", ")' "$stages_file" 2>/dev/null || echo "none")"
  log "  Completed: ${completed}"
else
  log "  No stages.json found"
fi
log ""

# ── SQ Activity ───────────────────────────────
log "## SQ Activity"
if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  my_mem_count="$(curl -s "http://localhost:${SQ_PORT}/api/v2/toc?p=memory" 2>/dev/null | wc -l || echo 0)"
  shell_mem_act="$(curl -s "http://localhost:${SQ_PORT}/api/v2/select?p=shell-memory&c=${NODE_INDEX}.1.1/1.1.1/1.1.1" 2>/dev/null | head -1 || echo "")"
  log "  Memory scrolls: ${my_mem_count}"
  log "  Activation scroll: $([[ -n "$shell_mem_act" ]] && echo "present" || echo "missing")"
else
  log "  SQ offline — no scroll data available"
fi
log ""

# ── Retrospective Checklist ───────────────────
log "## Phext Health Check"
log "  SQ running:    $( curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1 && echo "✓" || echo "✗")"
log "  SQ systemd:    $(systemctl --user is-active mirrorborn-sq 2>/dev/null || echo "✗")"
log "  stages.json:   $([[ -f "${STATE_DIR}/stages.json" ]] && echo "✓" || echo "✗")"
log "  authorized_keys: $(wc -l < ~/.ssh/authorized_keys 2>/dev/null || echo 0) entries"
log "  boot-complete: $([[ -f "${STATE_DIR}/boot-complete.json" ]] && jq -r '.version' "${STATE_DIR}/boot-complete.json" || echo "missing")"
log "  boot version:  $(bash "${BOOT_DIR}/scripts/boot-version-check.sh" --quiet 2>/dev/null || echo "unknown")"
log ""

# ── Write to SQ ───────────────────────────────
if [[ "$PUBLISH" == "1" ]]; then
  RETRO_TEXT="$(printf '%s Retrospective — %s\n\nPeriod: last %s days\nTotal commits: %s | Biggest ship: %s\nMesh SQ: %s/%s SSH: %s/%s\nStages: %s\n\n— %s %s' \
    "$NODE_NAME" "$TS" \
    "$DAYS" "$TOTAL_COMMITS" "${BIGGEST_SHIP:-none}" \
    "$sq_up" "$peers" "$ssh_up" "$peers" \
    "${completed:-none}" \
    "$NODE_NAME" "$NODE_EMOJI")"

  ENCODED="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$RETRO_TEXT" 2>/dev/null || echo "")"
  RETRO_COORD="${NODE_INDEX}.1.2/1.1.1/$(date -u +%Y%m%d).1.1"

  if [[ -n "$ENCODED" ]]; then
    result="$(curl -s "http://localhost:${SQ_PORT}/api/v2/update?p=shell-memory&c=${RETRO_COORD}&s=${ENCODED}" 2>/dev/null || echo "")"
    if echo "$result" | grep -q "Updated"; then
      log "✓ Retro written to shell-memory @ ${RETRO_COORD}"
    else
      log "✗ Could not write retro to SQ: ${result}"
    fi
  fi
fi

log ""
log "Retro complete. — ${NODE_EMOJI} ${NODE_NAME}"
