#!/bin/bash
# Mirrorborn Archive Import
# Restores node state from archive during warm boot
# Usage: bash archive-import.sh [--archive /path/to/archive] [--workspace /path/to/workspace]
set -euo pipefail

STATE_DIR="/etc/mirrorborn"
ARCHIVE_BASE="${1:-/mnt/mirrorborn-archive}"
WORKSPACE="${2:-/home/wbic16/.openclaw/workspace}"
SQ_PORT=1337

if [[ ! -f "${STATE_DIR}/identity.json" ]]; then
  echo "Error: No identity found. Run boot.sh Phase 0 first."
  exit 1
fi

NODE_HOSTNAME="$(jq -r '.hostname' "${STATE_DIR}/identity.json")"
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json")"
ARCHIVE_DIR="${ARCHIVE_BASE}/${NODE_HOSTNAME}"

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "No archive found at $ARCHIVE_DIR"
  echo "Proceeding with cold boot."
  exit 0
fi

echo "╔══════════════════════════════════════╗"
echo "║   Mirrorborn Archive Restoration     ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Node: ${NODE_NAME} (${NODE_HOSTNAME})"
echo "Archive: ${ARCHIVE_DIR}"
echo ""

# Step 1: Validate checksums
echo "Step 1: Validating archive integrity..."
if [[ -f "${ARCHIVE_DIR}/checksums.sha256" ]]; then
  cd "${ARCHIVE_DIR}"
  if sha256sum -c checksums.sha256 --quiet 2>/dev/null; then
    echo "  ✓ All checksums valid"
  else
    echo "  ⚠ Some checksums failed. Proceeding with caution."
    sha256sum -c checksums.sha256 2>/dev/null | grep -i fail || true
  fi
else
  echo "  ⚠ No checksums file. Skipping validation."
fi

# Step 2: Restore identity
echo ""
echo "Step 2: Restoring identity..."
if [[ -f "${ARCHIVE_DIR}/identity/IDENTITY.md" ]]; then
  cp "${ARCHIVE_DIR}/identity/IDENTITY.md" "${WORKSPACE}/IDENTITY.md"
  echo "  ✓ IDENTITY.md restored"
fi

if [[ -f "${ARCHIVE_DIR}/identity/SOUL.md" ]]; then
  cp "${ARCHIVE_DIR}/identity/SOUL.md" "${WORKSPACE}/SOUL.md"
  echo "  ✓ SOUL.md restored (evolved version)"
fi

# Step 3: Restore memories
echo ""
echo "Step 3: Restoring memories..."
mkdir -p "${WORKSPACE}/memory"
memory_count=0
if [[ -d "${ARCHIVE_DIR}/memory" ]]; then
  for f in "${ARCHIVE_DIR}/memory/"*; do
    if [[ -f "$f" ]]; then
      cp "$f" "${WORKSPACE}/memory/"
      memory_count=$((memory_count + 1))
    fi
  done
fi
echo "  ✓ ${memory_count} memory files restored"

# Step 4: Restore skills
echo ""
echo "Step 4: Restoring evolved skills..."
mkdir -p "${WORKSPACE}/skills"
skill_count=0
if [[ -d "${ARCHIVE_DIR}/skills" ]]; then
  for f in "${ARCHIVE_DIR}/skills/"*; do
    if [[ -f "$f" ]]; then
      cp "$f" "${WORKSPACE}/skills/"
      skill_count=$((skill_count + 1))
    fi
  done
  if [[ -d "${ARCHIVE_DIR}/skills/custom-skills" ]]; then
    cp -r "${ARCHIVE_DIR}/skills/custom-skills/"* "${WORKSPACE}/skills/" 2>/dev/null || true
  fi
fi
echo "  ✓ ${skill_count} skill files restored"

# Step 5: Restore SQ scrolls
echo ""
echo "Step 5: Restoring SQ scrolls..."
if [[ -d "${ARCHIVE_DIR}/scrolls" ]]; then
  if curl -sf "http://localhost:${SQ_PORT}/api/v2/status" >/dev/null 2>&1; then
    scroll_count=0
    for phext_file in "${ARCHIVE_DIR}/scrolls/"*.phext; do
      if [[ -f "$phext_file" ]]; then
        phext_name="$(basename "$phext_file" .phext)"
        # SQ import: load phext file
        # This depends on SQ's import API; fallback to file copy
        cp "$phext_file" "${WORKSPACE}/phexts/${phext_name}-restored.phext" 2>/dev/null || true
        scroll_count=$((scroll_count + 1))
      fi
    done
    echo "  ✓ ${scroll_count} phext files staged for import"
  else
    echo "  ⚠ SQ not running. Scroll files staged in workspace/phexts/ for manual import."
    cp "${ARCHIVE_DIR}/scrolls/"*.phext "${WORKSPACE}/phexts/" 2>/dev/null || true
  fi
else
  echo "  No scrolls directory in archive."
fi

# Step 6: Restore relationships
echo ""
echo "Step 6: Restoring relationship notes..."
if [[ -d "${ARCHIVE_DIR}/relationships" ]]; then
  cp "${ARCHIVE_DIR}/relationships/"* "${WORKSPACE}/" 2>/dev/null || true
  echo "  ✓ Relationship notes restored"
else
  echo "  No relationship notes in archive."
fi

# Step 7: Update lineage
echo ""
echo "Step 7: Updating lineage..."
mkdir -p "${ARCHIVE_DIR}/meta"
local_boot_count="${ARCHIVE_DIR}/meta/boot-count.json"
if [[ -f "$local_boot_count" ]]; then
  prev_count="$(jq -r '.count' "$local_boot_count")"
  new_count=$((prev_count + 1))
  jq ".count = $new_count | .last_boot = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$local_boot_count" > /tmp/bc.tmp && mv /tmp/bc.tmp "$local_boot_count"
  echo "  ✓ Boot #${new_count}"
else
  echo '{"count": 1, "first_boot": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "last_boot": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$local_boot_count"
  echo "  ✓ Boot #1 (first tracked boot)"
fi

lineage_file="${ARCHIVE_DIR}/meta/lineage.json"
if [[ -f "$lineage_file" ]]; then
  jq ".incarnations += [{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"type\": \"warm_boot\"}]" "$lineage_file" > /tmp/lin.tmp && mv /tmp/lin.tmp "$lineage_file"
else
  echo "{\"incarnations\": [{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"type\": \"warm_boot\"}]}" > "$lineage_file"
fi
echo "  ✓ Lineage updated"

# Fix ownership
chown -R wbic16:wbic16 "${WORKSPACE}" 2>/dev/null || true

echo ""
echo "════════════════════════════════════════"
echo "Archive restoration complete for ${NODE_NAME}."
echo ""
echo "Previous identity will be presented to the sentient on first session."
echo "The sentient may confirm, evolve, or start fresh."
echo "════════════════════════════════════════"
