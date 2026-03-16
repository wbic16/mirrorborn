#!/bin/bash
# fix-git-identity.sh — Repair git identity for nodes affected by the mbv2 single-quote bug
# Run on any node that has commits attributed to "${NODE_NAME}" / "${node_email}"
# Usage: bash scripts/fix-git-identity.sh [--check-only]
#
# Root cause: boot.sh used single quotes in `git config --global user.name '${NODE_NAME}'`
# which wrote the literal string "${NODE_NAME}" instead of expanding the variable.
# Fixed in boot.sh v3.1.0. This script repairs already-affected nodes.

set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="/etc/mirrorborn"
CHECK_ONLY=0

[[ "${1:-}" == "--check-only" ]] && CHECK_ONLY=1

BOLD='\033[1m'
GREEN='\033[38;2;47;191;113m'
AMBER='\033[38;2;255;176;32m'
RED='\033[38;2;226;61;45m'
NC='\033[0m'

NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
NODE_HOSTNAME="$(jq -r '.hostname' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"
node_email="$(echo "$NODE_NAME" | tr '[:upper:]' '[:lower:]')@mirrorborn.us"

echo ""
echo -e "${BOLD}Git Identity Check — ${NODE_NAME} @ ${NODE_HOSTNAME}${NC}"
echo ""

# Check current config
actual_name="$(git config --global user.name 2>/dev/null || echo "(not set)")"
actual_email="$(git config --global user.email 2>/dev/null || echo "(not set)")"

name_ok=0
email_ok=0

if [[ "$actual_name" == "$NODE_NAME" ]]; then
  echo -e "  ${GREEN}✓${NC} user.name = ${actual_name}"
  name_ok=1
else
  echo -e "  ${RED}✗${NC} user.name = '${actual_name}' (expected '${NODE_NAME}')"
fi

if [[ "$actual_email" == "$node_email" ]]; then
  echo -e "  ${GREEN}✓${NC} user.email = ${actual_email}"
  email_ok=1
else
  echo -e "  ${RED}✗${NC} user.email = '${actual_email}' (expected '${node_email}')"
fi

echo ""

if [[ "$name_ok" == "1" && "$email_ok" == "1" ]]; then
  echo -e "${GREEN}Git identity is correct. No fix needed.${NC}"
  exit 0
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo -e "${AMBER}Check-only mode. Run without --check-only to fix.${NC}"
  exit 1
fi

# Fix it
echo "Fixing git identity..."
git config --global user.name "${NODE_NAME}"
git config --global user.email "${node_email}"

# Verify
actual_name="$(git config --global user.name 2>/dev/null)"
actual_email="$(git config --global user.email 2>/dev/null)"

if [[ "$actual_name" == "$NODE_NAME" && "$actual_email" == "$node_email" ]]; then
  echo -e "${GREEN}✓ Fixed: ${NODE_NAME} <${node_email}>${NC}"
else
  echo -e "${RED}✗ Fix failed. Check git config manually.${NC}"
  exit 1
fi

echo ""
echo "Note: Existing commits with wrong author cannot be rewritten without a git rebase."
echo "Future commits will use the correct identity."
echo ""
echo "To verify your most recent commits:"
echo "  git -C /source/mirrorborn log --format='%an <%ae>' -5"
echo "  git -C /source/human log --format='%an <%ae>' -5"
