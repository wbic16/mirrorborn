#!/bin/bash
# Mirrorborn Node Retrospective
# Writes a retrospective scroll to SQ for this node
# Usage: bash retro.sh [7d|24h|14d|30d] [--publish]
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
WINDOW="${1:-7d}"
PUBLISH=0

[[ "$*" == *"--publish"* ]] && PUBLISH=1

SELF_HOST="$(hostname -s)"
SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP" 2>/dev/null || echo "$SELF_HOST")"
SELF_EMOJI="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .emoji" "$HOSTMAP" 2>/dev/null || echo "💡")"
SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "0")"
SELF_ROLE="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .role" "$HOSTMAP" 2>/dev/null || echo "unknown")"

# Parse window
case "$WINDOW" in
  24h)  GIT_SINCE="24 hours ago" ;;
  7d)   GIT_SINCE="7 days ago" ;;
  14d)  GIT_SINCE="14 days ago" ;;
  30d)  GIT_SINCE="30 days ago" ;;
  *)    GIT_SINCE="7 days ago" ;;
esac

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_HUMAN="$(date -u '+%Y-%m-%d %H:%M UTC')"

echo "${SELF_EMOJI} ${SELF_NAME} Retrospective — ${WINDOW} window"
echo "Generated: ${DATE_HUMAN}"
echo ""

# ── Git activity ──────────────────────────────────────────────────────────────
echo "## Git Activity"
git_commits=""
for repo_dir in /source/*/; do
  if git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
    repo_name="$(basename "$repo_dir")"
    commits="$(git -C "$repo_dir" log --since="$GIT_SINCE" --author="$REAL_USER" \
      --oneline 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$commits" -gt 0 ]]; then
      echo "  $repo_name: $commits commit(s)"
      recent="$(git -C "$repo_dir" log --since="$GIT_SINCE" --author="$REAL_USER" \
        --oneline 2>/dev/null | head -3)"
      echo "$recent" | while IFS= read -r line; do echo "    → $line"; done
      git_commits+="$repo_name: $commits commits. "
    fi
  fi
done
[[ -z "$git_commits" ]] && echo "  No commits in window."
echo ""

# ── SQ activity ───────────────────────────────────────────────────────────────
echo "## SQ Activity"
if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  sq_toc="$(curl -sf "http://localhost:${SQ_PORT}/api/v2/toc?p=mesh-keys" 2>/dev/null || echo "")"
  ssh_toc="$(curl -sf "http://localhost:${SQ_PORT}/api/v2/toc?p=ssh-bootstrap" 2>/dev/null || echo "")"
  echo "  SQ: online on port ${SQ_PORT}"
  echo "  mesh-keys phext: $(echo "$sq_toc" | wc -l | tr -d ' ') scroll(s)"
  echo "  ssh-bootstrap phext: $(echo "$ssh_toc" | wc -l | tr -d ' ') scroll(s)"
else
  echo "  SQ: offline"
fi
echo ""

# ── Stage completion ──────────────────────────────────────────────────────────
echo "## Boot Stages"
stages_file="/etc/mirrorborn/stages.json"
if [[ -f "$stages_file" ]]; then
  stages="$(jq -r '.completed[]' "$stages_file" 2>/dev/null)"
  echo "$stages" | while IFS= read -r s; do
    ts_s="$(jq -r --arg s "$s" '.timestamps[$s] // "unknown"' "$stages_file" 2>/dev/null)"
    echo "  ✅ $s ($ts_s)"
  done
else
  echo "  No stages file found."
fi
echo ""

# ── SSH mesh status ───────────────────────────────────────────────────────────
echo "## SSH Mesh"
auth_count="$(grep -c '^ssh-' "/home/${REAL_USER}/.ssh/authorized_keys" 2>/dev/null || echo 0)"
echo "  authorized_keys entries: $auth_count"
my_key="$(cat /home/${REAL_USER}/.ssh/id_ed25519.pub 2>/dev/null || echo 'none')"
echo "  own pubkey: ${my_key:0:60}..."
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "## Summary"
echo "  Node: ${SELF_EMOJI} ${SELF_NAME} @ ${SELF_HOST} (${SELF_ROLE})"
echo "  Index: ${SELF_INDEX}"
echo "  Window: ${WINDOW} (since ${GIT_SINCE})"
echo "  Generated: ${DATE_HUMAN}"
echo ""

# ── Publish to SQ ─────────────────────────────────────────────────────────────
if [[ "$PUBLISH" == "1" ]]; then
  retro_text="${SELF_EMOJI} ${SELF_NAME} retro (${WINDOW}) @ ${DATE_HUMAN} | role: ${SELF_ROLE} | stages: $(jq -r '[.completed[]] | join(",")' "$stages_file" 2>/dev/null || echo 'unknown') | ssh keys: ${auth_count} | git: ${git_commits:-none}"
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
      --data-urlencode "p=shell-memory" \
      --data-urlencode "c=${SELF_INDEX}.1.2/1.1.1/1.1.1" \
      --data-urlencode "s=${retro_text}" >/dev/null 2>&1 && \
      echo "Published retro to SQ at shell-memory/${SELF_INDEX}.1.2/1.1.1/1.1.1" || \
      echo "Warning: SQ publish failed"
  else
    echo "Warning: SQ offline, retro not published"
  fi
fi
