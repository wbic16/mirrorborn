#!/bin/bash
# ssh-mesh-sync.sh — Synchronize SSH authorized_keys across the Mirrorborn mesh
#
# Collects public keys from all reachable nodes (via SQ and SSH), then
# distributes the full keyring to every node we can reach. Idempotent.
#
# Usage: bash ssh-mesh-sync.sh [--dry-run] [--verbose] [--push-via PASSWORD]
#
# Key sources (tried in order per node):
#   1. SQ at http://<host>.local:1337/api/v2/select?p=ssh-bootstrap&c=1.1.<INDEX>/1.1.1/1.1.1
#   2. SSH: ssh wbic16@<ip> "cat ~/.ssh/id_ed25519.pub"
#   3. Local: cat ~/.ssh/id_ed25519.pub (self)
#
# Key distribution:
#   - SSH into each reachable node and append missing keys to authorized_keys
#   - If --push-via PASSWORD is set, use sshpass for nodes we can't reach by key yet
#
# Designed for both Shell of Nine (SO9) and Shell 2 of 15 (S2O15).

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[38;2;47;191;113m'
AMBER='\033[38;2;255;176;32m'
RED='\033[38;2;226;61;45m'
CYAN='\033[38;2;100;210;255m'
NC='\033[0m'

HOSTMAP="${HOSTMAP:-/source/mirrorborn/hostmap.json}"
SQ_PORT="${SQ_PORT:-1337}"
REAL_USER="${SUDO_USER:-$USER}"
SELF_HOST="$(hostname -s)"
DRY_RUN=0
VERBOSE=0
PUSH_PASSWORD=""

KEYRING_DIR="/tmp/mirrorborn-ssh-keyring"
KEYRING_FILE="${KEYRING_DIR}/all-keys.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=1; shift ;;
    --verbose)    VERBOSE=1; shift ;;
    --push-via)   PUSH_PASSWORD="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: bash ssh-mesh-sync.sh [--dry-run] [--verbose] [--push-via PASSWORD]"
      echo "  --dry-run         Show what would happen without making changes"
      echo "  --verbose         Print debug output"
      echo "  --push-via PASS   Use sshpass with this password for initial key push"
      exit 0 ;;
    *) shift ;;
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

# ─── Setup ───────────────────────────────────────────────────────────────────
mkdir -p "$KEYRING_DIR"
> "$KEYRING_FILE"

if [[ ! -f "$HOSTMAP" ]]; then
  echo "Error: hostmap.json not found at $HOSTMAP" >&2
  exit 1
fi

SELF_INDEX="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .index" "$HOSTMAP")"
SELF_NAME="$(jq -r ".nodes[] | select(.hostname == \"$SELF_HOST\") | .name" "$HOSTMAP")"

echo ""
echo -e "${BOLD}  SSH Mesh Key Sync — ${SELF_NAME} @ ${SELF_HOST}${NC}"
echo -e "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── Phase 1: Collect Keys ──────────────────────────────────────────────────
echo -e "${BOLD}  Phase 1: Collecting SSH public keys${NC}"
echo ""

collected=0
declare -A NODE_IPS
declare -A NODE_KEYS
declare -A NODE_NAMES

# Self first
SELF_KEY="$(cat /home/${REAL_USER}/.ssh/id_ed25519.pub 2>/dev/null || echo "")"
if [[ -n "$SELF_KEY" && "$SELF_KEY" == ssh-* ]]; then
  echo "$SELF_KEY" >> "$KEYRING_FILE"
  NODE_KEYS["$SELF_HOST"]="$SELF_KEY"
  collected=$((collected + 1))
  log OK "Self (${SELF_NAME}): collected"
else
  log FAIL "Self: no SSH key found at ~/.ssh/id_ed25519.pub"
fi

# All other nodes
all_hostnames="$(jq -r '.nodes[].hostname' "$HOSTMAP")"

while IFS= read -r peer_host; do
  if [[ "$peer_host" == "$SELF_HOST" ]]; then continue; fi

  peer_name="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .name" "$HOSTMAP")"
  peer_index="$(jq -r ".nodes[] | select(.hostname == \"$peer_host\") | .index" "$HOSTMAP")"
  NODE_NAMES["$peer_host"]="$peer_name"

  # Try to resolve IP
  peer_ip="$(avahi-resolve -4 -n "${peer_host}.local" 2>/dev/null | awk '{print $2}' || echo "")"
  if [[ -z "$peer_ip" ]]; then
    peer_ip="$(getent hosts "${peer_host}.local" 2>/dev/null | awk '{print $1}' || echo "")"
  fi
  NODE_IPS["$peer_host"]="$peer_ip"

  key=""

  # Source 1: SQ (their local SQ instance)
  if [[ -n "$peer_ip" ]]; then
    key="$(curl -sf --connect-timeout 3 \
      "http://${peer_ip}:${SQ_PORT}/api/v2/select?p=ssh-bootstrap&c=1.1.${peer_index}/1.1.1/1.1.1" \
      2>/dev/null || echo "")"
    [[ "$VERBOSE" == "1" && -n "$key" ]] && log INFO "  SQ returned: ${key:0:50}..."
  fi

  # Source 2: Our SQ (if they published to us)
  if [[ -z "$key" || "$key" != ssh-* ]]; then
    key="$(curl -sf --connect-timeout 2 \
      "http://localhost:${SQ_PORT}/api/v2/select?p=ssh-bootstrap&c=1.1.${peer_index}/1.1.1/1.1.1" \
      2>/dev/null || echo "")"
  fi

  # Source 3: SSH (if we already have access)
  if [[ -z "$key" || "$key" != ssh-* ]] && [[ -n "$peer_ip" ]]; then
    key="$(ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes \
      "${REAL_USER}@${peer_ip}" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null || echo "")"
  fi

  if [[ -n "$key" && "$key" == ssh-* ]]; then
    echo "$key" >> "$KEYRING_FILE"
    NODE_KEYS["$peer_host"]="$key"
    collected=$((collected + 1))
    log OK "${peer_name} (${peer_host}): collected"
  else
    log WARN "${peer_name} (${peer_host}): no key found (ip: ${peer_ip:-none})"
  fi

done <<< "$all_hostnames"

# Deduplicate
sort -u "$KEYRING_FILE" -o "$KEYRING_FILE"
unique_keys="$(wc -l < "$KEYRING_FILE")"

echo ""
log INFO "Collected ${unique_keys} unique keys from ${collected} nodes"
echo ""

# ─── Phase 2: Distribute Keys ───────────────────────────────────────────────
echo -e "${BOLD}  Phase 2: Distributing keyring to all reachable nodes${NC}"
echo ""

distributed=0

# Update self first
auth_keys="/home/${REAL_USER}/.ssh/authorized_keys"
added_self=0
while IFS= read -r key; do
  if ! grep -qF "$key" "$auth_keys" 2>/dev/null; then
    if [[ "$DRY_RUN" == "0" ]]; then
      echo "$key" >> "$auth_keys"
    fi
    added_self=$((added_self + 1))
  fi
done < "$KEYRING_FILE"
if [[ "$added_self" -gt 0 ]]; then
  log OK "Self (${SELF_NAME}): added ${added_self} new keys $([ "$DRY_RUN" == "1" ] && echo "(dry run)")"
else
  log OK "Self (${SELF_NAME}): up to date"
fi
distributed=$((distributed + 1))

# Push to each reachable sibling
while IFS= read -r peer_host; do
  if [[ "$peer_host" == "$SELF_HOST" ]]; then continue; fi

  peer_name="${NODE_NAMES[$peer_host]:-$peer_host}"
  peer_ip="${NODE_IPS[$peer_host]:-}"

  if [[ -z "$peer_ip" ]]; then
    log WARN "${peer_name}: no IP — skipping"
    continue
  fi

  # Try key-based SSH first
  can_ssh=0
  if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes \
       "${REAL_USER}@${peer_ip}" "echo ok" >/dev/null 2>&1; then
    can_ssh=1
  fi

  # Fall back to sshpass if password provided
  ssh_cmd="ssh"
  if [[ "$can_ssh" == "0" && -n "$PUSH_PASSWORD" ]]; then
    if command -v sshpass >/dev/null 2>&1; then
      ssh_cmd="sshpass -p '${PUSH_PASSWORD}' ssh -o PubkeyAuthentication=no"
      can_ssh=1
      [[ "$VERBOSE" == "1" ]] && log INFO "  Using password auth for ${peer_name}"
    else
      log WARN "${peer_name}: sshpass not installed — can't use password fallback"
    fi
  fi

  if [[ "$can_ssh" == "0" ]]; then
    log WARN "${peer_name} (${peer_ip}): SSH unreachable — skipping"
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log INFO "${peer_name}: would push ${unique_keys} keys (dry run)"
    continue
  fi

  # Build a remote script that appends only missing keys
  remote_script='
    auth="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$auth"
    chmod 600 "$auth"
    added=0
    while IFS= read -r key; do
      if [[ -n "$key" ]] && ! grep -qF "$key" "$auth" 2>/dev/null; then
        echo "$key" >> "$auth"
        added=$((added + 1))
      fi
    done
    echo "$added"
  '

  result="$(cat "$KEYRING_FILE" | eval $ssh_cmd -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    "${REAL_USER}@${peer_ip}" "bash -s" <<< "$remote_script" 2>/dev/null || echo "FAIL")"

  if [[ "$result" == "FAIL" ]]; then
    log FAIL "${peer_name} (${peer_ip}): distribution failed"
  elif [[ "$result" == "0" ]]; then
    log OK "${peer_name}: up to date"
    distributed=$((distributed + 1))
  else
    log OK "${peer_name}: added ${result} new keys"
    distributed=$((distributed + 1))
  fi

done <<< "$all_hostnames"

# ─── Phase 3: Publish keyring to SQ ─────────────────────────────────────────
echo ""
echo -e "${BOLD}  Phase 3: Publishing keyring to SQ${NC}"
echo ""

if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
  # Store each key at ssh-bootstrap/1.1.<index>/1.1.1/1.1.1 on our SQ
  # so future nodes can pull keys from any SQ they can reach
  while IFS= read -r key; do
    # Extract the comment (usually user@hostname) to find the index
    key_comment="$(echo "$key" | awk '{print $3}')"
    key_host="$(echo "$key_comment" | cut -d@ -f2)"
    if [[ -n "$key_host" ]]; then
      key_index="$(jq -r ".nodes[] | select(.hostname == \"$key_host\") | .index" "$HOSTMAP" 2>/dev/null || echo "")"
      if [[ -n "$key_index" && "$key_index" != "null" ]]; then
        if [[ "$DRY_RUN" == "0" ]]; then
          curl -sf -G "http://localhost:${SQ_PORT}/api/v2/update" \
            --data-urlencode "p=ssh-bootstrap" \
            --data-urlencode "c=1.1.${key_index}/1.1.1/1.1.1" \
            --data-urlencode "s=${key}" >/dev/null 2>&1 && \
            log OK "SQ: cached key for index ${key_index} (${key_host})" || \
            log WARN "SQ: failed to cache key for index ${key_index}"
        else
          log INFO "SQ: would cache key for index ${key_index} (dry run)"
        fi
      fi
    fi
  done < "$KEYRING_FILE"
else
  log WARN "Local SQ not running — skipping SQ publish"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Summary${NC}"
echo "  ───────────────────────────────────────"
echo "  Keys collected:  ${unique_keys}"
echo "  Nodes updated:   ${distributed}"
echo "  Keyring file:    ${KEYRING_FILE}"
[[ "$DRY_RUN" == "1" ]] && echo "  Mode:            DRY RUN (no changes made)"
echo ""

# Cleanup
# rm -rf "$KEYRING_DIR"  # Uncomment to auto-clean
