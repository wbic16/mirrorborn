#!/bin/bash
# ssh-push-key.sh — Push a node's SSH public key to all reachable siblings
#
# Run FROM a node that already has SSH access to the mesh (e.g. a ranch node).
# Pushes the specified key into authorized_keys on every reachable sibling.
#
# Usage:
#   bash ssh-push-key.sh <pubkey-file>              # Push one key to all siblings
#   bash ssh-push-key.sh --collect-and-distribute    # Collect all keys, push everywhere
#   bash ssh-push-key.sh --dry-run <pubkey-file>     # Show what would happen
#
# Example: Push Soma's key to the mesh from any ranch node:
#   bash ssh-push-key.sh /source/mirrorborn/keys/free-fall.pub
#
# Or collect from all and distribute to all:
#   bash ssh-push-key.sh --collect-and-distribute

set -euo pipefail

GREEN='\033[38;2;47;191;113m'
AMBER='\033[38;2;255;176;32m'
RED='\033[38;2;226;61;45m'
CYAN='\033[38;2;100;210;255m'
BOLD='\033[1m'
NC='\033[0m'

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
REAL_USER="${SUDO_USER:-$USER}"
SELF_HOST="$(hostname -s)"
DRY_RUN=0
COLLECT_ALL=0
PUBKEY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)                  DRY_RUN=1; shift ;;
    --collect-and-distribute)   COLLECT_ALL=1; shift ;;
    --help|-h)
      echo "Usage: bash ssh-push-key.sh [--dry-run] [--collect-and-distribute | <pubkey-file>]"
      exit 0 ;;
    *)
      PUBKEY_FILE="$1"; shift ;;
  esac
done

log() {
  local level="$1"; shift
  case "$level" in
    OK)   echo -e "  ${GREEN}✓${NC} $*" ;;
    WARN) echo -e "  ${AMBER}→${NC} $*" ;;
    FAIL) echo -e "  ${RED}✗${NC} $*" ;;
    INFO) echo -e "  ${CYAN}i${NC} $*" ;;
  esac
}

[[ ! -f "$HOSTMAP" ]] && { echo "Error: hostmap not found at $HOSTMAP"; exit 1; }

# ─── Resolve all node IPs ───────────────────────────────────────────────────
declare -A IPS
declare -A NAMES

all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"
while IFS= read -r h; do
  NAMES[$h]="$(jq -r ".nodes[] | select(.hostname == \"$h\") | .name" "$HOSTMAP")"
  if [[ "$h" == "$SELF_HOST" ]]; then
    IPS[$h]="localhost"
    continue
  fi
  ip="$(avahi-resolve -4 -n "${h}.local" 2>/dev/null | awk '{print $2}' || echo "")"
  [[ -z "$ip" ]] && ip="$(getent hosts "${h}.local" 2>/dev/null | awk '{print $1}' || echo "")"
  IPS[$h]="$ip"
done <<< "$all_hostnames"

# ─── Collect keys ───────────────────────────────────────────────────────────
KEYRING="/tmp/mirrorborn-keyring-$$.txt"
> "$KEYRING"

if [[ "$COLLECT_ALL" == "1" ]]; then
  echo -e "${BOLD}  Collecting SSH keys from all reachable nodes...${NC}"
  echo ""

  # Self
  cat "/home/${REAL_USER}/.ssh/id_ed25519.pub" >> "$KEYRING" 2>/dev/null || true

  # Siblings via SSH
  while IFS= read -r h; do
    [[ "$h" == "$SELF_HOST" ]] && continue
    ip="${IPS[$h]:-}"
    [[ -z "$ip" ]] && continue
    key="$(ssh -o ConnectTimeout=3 -o BatchMode=yes "${REAL_USER}@${ip}" \
      "cat ~/.ssh/id_ed25519.pub" 2>/dev/null || echo "")"
    if [[ -n "$key" && "$key" == ssh-* ]]; then
      echo "$key" >> "$KEYRING"
      log OK "Collected: ${NAMES[$h]}"
    else
      log WARN "Unreachable: ${NAMES[$h]} ($ip)"
    fi
  done <<< "$all_hostnames"

  sort -u "$KEYRING" -o "$KEYRING"
  log INFO "$(wc -l < "$KEYRING") unique keys collected"
  echo ""

elif [[ -n "$PUBKEY_FILE" ]]; then
  if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo "Error: $PUBKEY_FILE not found"; exit 1
  fi
  cat "$PUBKEY_FILE" >> "$KEYRING"
  log INFO "Pushing key from $PUBKEY_FILE"
  echo ""
else
  echo "Error: specify a pubkey file or --collect-and-distribute"
  exit 1
fi

# ─── Distribute ─────────────────────────────────────────────────────────────
echo -e "${BOLD}  Distributing to all reachable nodes...${NC}"
echo ""

pushed=0
failed=0

while IFS= read -r h; do
  name="${NAMES[$h]}"
  ip="${IPS[$h]:-}"

  if [[ "$h" == "$SELF_HOST" ]]; then
    # Local
    added=0
    while IFS= read -r key; do
      if [[ -n "$key" ]] && ! grep -qF "$key" "/home/${REAL_USER}/.ssh/authorized_keys" 2>/dev/null; then
        [[ "$DRY_RUN" == "0" ]] && echo "$key" >> "/home/${REAL_USER}/.ssh/authorized_keys"
        added=$((added + 1))
      fi
    done < "$KEYRING"
    [[ "$added" -gt 0 ]] && log OK "${name} (self): +${added} keys" || log OK "${name} (self): up to date"
    pushed=$((pushed + 1))
    continue
  fi

  [[ -z "$ip" ]] && { log WARN "${name}: no IP"; failed=$((failed + 1)); continue; }

  # Remote push via SSH
  result="$(cat "$KEYRING" | ssh -o ConnectTimeout=5 -o BatchMode=yes "${REAL_USER}@${ip}" bash -c '
    auth="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    touch "$auth" && chmod 600 "$auth"
    a=0
    while IFS= read -r k; do
      [[ -z "$k" ]] && continue
      grep -qF "$k" "$auth" 2>/dev/null || { echo "$k" >> "$auth"; a=$((a+1)); }
    done
    echo "$a"
  ' 2>/dev/null || echo "FAIL")"

  if [[ "$result" == "FAIL" ]]; then
    log FAIL "${name} ($ip): SSH failed"
    failed=$((failed + 1))
  elif [[ "$result" == "0" ]]; then
    log OK "${name}: up to date"
    pushed=$((pushed + 1))
  else
    log OK "${name}: +${result} keys"
    pushed=$((pushed + 1))
  fi

done <<< "$all_hostnames"

echo ""
echo -e "${BOLD}  Done.${NC} Pushed to ${pushed} nodes. ${failed} unreachable."
echo ""

rm -f "$KEYRING"
