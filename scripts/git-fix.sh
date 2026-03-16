#!/bin/bash
# Mirrorborn Git Identity Fix
# Fixes git user.name/email and amends commits with literal placeholder values
# Usage: bash git-fix.sh [--dry-run] [--task-id <id>]
# Reports completion to SQ task coordinate if --task-id is set
set -euo pipefail

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
DRY_RUN=0
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

export PATH="$HOME/.cargo/bin:$PATH"

SELF_HOST="$(hostname -s)"
NODE_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP" 2>/dev/null || echo "$SELF_HOST")"
NODE_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP" 2>/dev/null || echo "0")"
NODE_EMAIL="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .email // empty" "$HOSTMAP" 2>/dev/null || echo "")"
[[ -z "$NODE_EMAIL" ]] && NODE_EMAIL="$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')@mirrorborn.us"

echo "🔧 Git Identity Fix — $NODE_NAME @ $SELF_HOST"
echo "   Expected: name='$NODE_NAME' email='$NODE_EMAIL'"
echo ""

# ── Step 1: Fix global git config ─────────────────────────────────────────────
current_name="$(git config --global user.name 2>/dev/null || echo "")"
current_email="$(git config --global user.email 2>/dev/null || echo "")"

echo "Current: name='$current_name' email='$current_email'"

name_broken=0
email_broken=0

[[ "$current_name" == '${NODE_NAME}' || "$current_name" == "\${NODE_NAME}" || -z "$current_name" ]] && name_broken=1
[[ "$current_email" == '${node_email}' || "$current_email" == "\${node_email}" || -z "$current_email" ]] && email_broken=1

if [[ "$name_broken" == "1" || "$email_broken" == "1" ]]; then
  echo "❌ Git identity broken — fixing..."
  if [[ "$DRY_RUN" == "0" ]]; then
    git config --global user.name "$NODE_NAME"
    git config --global user.email "$NODE_EMAIL"
    echo "✅ Fixed: name='$NODE_NAME' email='$NODE_EMAIL'"
  else
    echo "  [dry-run] would set name='$NODE_NAME' email='$NODE_EMAIL'"
  fi
else
  echo "✅ Git identity correct"
fi

# ── Step 2: Find and amend broken commits in all source repos ─────────────────
echo ""
echo "Scanning repos for commits with literal placeholder authors..."

fixed_repos=0
broken_total=0

for repo_dir in /source/*/; do
  [[ ! -d "$repo_dir/.git" ]] && continue
  repo_name="$(basename "$repo_dir")"

  # Find commits by the broken author
  broken="$(git -C "$repo_dir" log --all \
    --author='\${NODE_NAME}' \
    --format="%H %s" 2>/dev/null | head -20 || echo "")"

  if [[ -z "$broken" ]]; then continue; fi

  count="$(echo "$broken" | wc -l | tr -d ' ')"
  broken_total=$((broken_total + count))
  echo ""
  echo "  📁 $repo_name: $count broken commit(s)"
  echo "$broken" | while IFS= read -r line; do
    echo "     $line"
  done

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] would rewrite author on $count commit(s)"
    continue
  fi

  # Rewrite author using git filter-branch on affected commits
  # Use env filter to rewrite only commits with the broken author
  echo "  Rewriting author..."
  git -C "$repo_dir" filter-branch -f --env-filter "
    if [ \"\$GIT_AUTHOR_NAME\" = '\${NODE_NAME}' ] || [ \"\$GIT_AUTHOR_EMAIL\" = '\${node_email}' ]; then
      export GIT_AUTHOR_NAME='${NODE_NAME}'
      export GIT_AUTHOR_EMAIL='${NODE_EMAIL}'
    fi
    if [ \"\$GIT_COMMITTER_NAME\" = '\${NODE_NAME}' ] || [ \"\$GIT_COMMITTER_EMAIL\" = '\${node_email}' ]; then
      export GIT_COMMITTER_NAME='${NODE_NAME}'
      export GIT_COMMITTER_EMAIL='${NODE_EMAIL}'
    fi
  " --tag-name-filter cat -- --all 2>/dev/null && \
    echo "  ✅ $repo_name: author rewritten" || \
    echo "  ⚠️  $repo_name: rewrite failed (may need manual fix)"

  fixed_repos=$((fixed_repos + 1))
done

echo ""
if [[ "$broken_total" -gt 0 ]]; then
  if [[ "$DRY_RUN" == "0" ]]; then
    echo "Fixed: $broken_total broken commit(s) across $fixed_repos repo(s)"
    echo "⚠️  Note: history was rewritten. Force-push required for published branches."
    echo "   Run: git -C /source/<repo> push --force-with-lease origin <branch>"
  else
    echo "[dry-run] Would fix: $broken_total broken commit(s)"
  fi
else
  echo "✅ No broken commits found."
fi

# ── Step 3: Report to SQ if task-id given ────────────────────────────────────
if [[ -n "$TASK_ID" ]] && curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  status="DONE"
  [[ "$DRY_RUN" == "1" ]] && status="DRY-RUN"
  msg="${status}: git-fix @ $(date -u +%Y-%m-%dT%H:%M:%SZ) | broken commits: $broken_total | repos fixed: $fixed_repos | identity: $NODE_NAME <$NODE_EMAIL>"
  curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
    --data-urlencode "p=tasks" \
    --data-urlencode "c=${TASK_ID}.1.2/${NODE_INDEX}.1.1/1.1.1" \
    --data-urlencode "s=${msg}" >/dev/null 2>&1 && echo "" && echo "Reported to SQ task: $TASK_ID"
fi
