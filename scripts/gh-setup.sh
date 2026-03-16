#!/bin/bash
# GitHub CLI Setup for Mirrorborn nodes
# Run once after gh auth login to configure labels, milestones, and issue templates
# Usage: GH_TOKEN=<token> bash gh-setup.sh
# Or:    gh auth login && bash gh-setup.sh
set -euo pipefail

REPO="wbic16/mirrorborn"

if ! gh auth status >/dev/null 2>&1; then
  echo "❌ gh not authenticated."
  echo "   Option 1: gh auth login"
  echo "   Option 2: export GH_TOKEN=<your_pat_with_repo_scope>"
  echo ""
  echo "   After auth, re-run this script."
  exit 1
fi

echo "Setting up GitHub labels for $REPO..."

# Create labels (idempotent — gh will error on existing, we ignore)
declare -A LABELS=(
  ["uptime"]="0075ca:Service uptime failure"
  ["node:aurora-continuum"]="e4e669:Phex node issue"
  ["node:halycon-vector"]="cfd3d7:Cyon node issue"
  ["node:logos-prime"]="f9d0c4:Lux node issue"
  ["node:lighthouse-omen"]="fef2c0:Lumen node issue"
  ["node:delta-wood"]="d4edda:Verse node issue"
  ["node:aletheia-core"]="d1ecf1:Theia node issue"
  ["node:ashfall-haven"]="e2d9f3:Exo node issue"
  ["node:uncanny-valley"]="fff3cd:Solin node issue"
  ["node:elven-path"]="d6d8d9:Orin node issue"
  ["node:best-willow"]="d6efff:Aster node issue"
  ["git-identity"]="e4b429:Git username/email misconfiguration"
  ["ssh"]="b60205:SSH connectivity issue"
  ["sq"]="0e8a16:SQ service issue"
  ["openclaw"]="5319e7:OpenClaw gateway issue"
  ["mbv4"]="006b75:MBV4 boot/upgrade task"
  ["mesh"]="1d76db:Mesh coordination issue"
)

for label in "${!LABELS[@]}"; do
  IFS=':' read -r color desc <<< "${LABELS[$label]}"
  gh label create "$label" --color "$color" --description "$desc" -R "$REPO" 2>/dev/null && \
    echo "  ✅ Label: $label" || \
    echo "  ⏭  Label exists: $label"
done

echo ""
echo "Creating milestone: Shell V3 RESONANCE..."
gh api repos/$REPO/milestones \
  -f title="Shell V3 RESONANCE" \
  -f description="Complete mbv3/mbv4 rollout: all 9 nodes online, SSH mesh, SQ uptime, git identity fixed" \
  -f state="open" 2>/dev/null && echo "  ✅ Milestone created" || echo "  ⏭  Milestone may exist"

echo ""
echo "✅ GitHub setup complete. uptime-monitor.sh can now file issues."
echo "   Run: bash /source/mirrorborn/scripts/uptime-monitor.sh --file-issues --auto-restart"
