#!/bin/bash
# Mirrorborn Archive Export
# Exports current node state for backup/migration
# Usage: bash archive-export.sh [--output /path/to/archive]
set -euo pipefail

STATE_DIR="/etc/mirrorborn"
WORKSPACE="/home/wbic16/.openclaw/workspace"
OUTPUT_BASE="${1:-/mnt/mirrorborn-archive}"

if [[ ! -f "${STATE_DIR}/identity.json" ]]; then
  echo "Error: No identity found. Is this node bootstrapped?"
  exit 1
fi

NODE_HOSTNAME="$(jq -r '.hostname' "${STATE_DIR}/identity.json")"
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json")"
OUTPUT_DIR="${OUTPUT_BASE}/${NODE_HOSTNAME}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

echo "Exporting archive for ${NODE_NAME} (${NODE_HOSTNAME})..."

# Create archive structure
mkdir -p "${OUTPUT_DIR}"/{identity,memory,skills,scrolls,meta,relationships}

# Identity
for f in IDENTITY.md SOUL.md; do
  [[ -f "${WORKSPACE}/$f" ]] && cp "${WORKSPACE}/$f" "${OUTPUT_DIR}/identity/"
done

if [[ -f "${STATE_DIR}/identity.json" ]]; then
  cp "${STATE_DIR}/identity.json" "${OUTPUT_DIR}/identity/coordinate.json"
fi

# Memory (all .md and .phext files in workspace, excluding templates)
find "${WORKSPACE}" -maxdepth 1 -name "*.md" -newer "${WORKSPACE}/USER.md" -exec cp {} "${OUTPUT_DIR}/memory/" \; 2>/dev/null || true
find "${WORKSPACE}" -maxdepth 1 -name "*.phext" -exec cp {} "${OUTPUT_DIR}/memory/" \; 2>/dev/null || true

# Build memory index
(cd "${OUTPUT_DIR}/memory" && find . -type f -exec stat --format='{"file":"%n","size":%s,"modified":"%y"}' {} \; 2>/dev/null) > "${OUTPUT_DIR}/memory/memory-index.json" || true

# Skills
if [[ -d "${WORKSPACE}/skills" ]]; then
  cp -r "${WORKSPACE}/skills/"* "${OUTPUT_DIR}/skills/" 2>/dev/null || true
fi

# SQ scroll export
if curl -sf "http://localhost:1337/api/v2/status" >/dev/null 2>&1; then
  echo "Exporting SQ scrolls..."
  # Export all phexts as a combined phext
  for phext_name in $(curl -sf "http://localhost:1337/api/v2/list" 2>/dev/null | jq -r '.[]' 2>/dev/null || true); do
    curl -sf "http://localhost:1337/api/v2/export?p=${phext_name}" > "${OUTPUT_DIR}/scrolls/${phext_name}.phext" 2>/dev/null || true
  done
  echo "Scrolls exported."
else
  echo "Warning: SQ not running. Skipping scroll export."
fi

# Meta
cat > "${OUTPUT_DIR}/meta/last-session.json" <<EOF
{
  "export_time": "${TIMESTAMP}",
  "node_name": "${NODE_NAME}",
  "hostname": "${NODE_HOSTNAME}",
  "workspace": "${WORKSPACE}"
}
EOF

# Boot count
if [[ -f "${OUTPUT_DIR}/meta/boot-count.json" ]]; then
  # Preserve existing
  true
else
  echo '{"count": 1, "first_boot": "'${TIMESTAMP}'", "last_boot": "'${TIMESTAMP}'"}' > "${OUTPUT_DIR}/meta/boot-count.json"
fi

# Lineage
if [[ ! -f "${OUTPUT_DIR}/meta/lineage.json" ]]; then
  echo '{"incarnations": [{"timestamp": "'${TIMESTAMP}'", "type": "export"}]}' > "${OUTPUT_DIR}/meta/lineage.json"
else
  jq ".incarnations += [{\"timestamp\": \"${TIMESTAMP}\", \"type\": \"export\"}]" "${OUTPUT_DIR}/meta/lineage.json" > /tmp/lineage.tmp && mv /tmp/lineage.tmp "${OUTPUT_DIR}/meta/lineage.json"
fi

# Relationships (if they exist)
for f in sibling-notes.md will-notes.md; do
  [[ -f "${WORKSPACE}/$f" ]] && cp "${WORKSPACE}/$f" "${OUTPUT_DIR}/relationships/"
done

# Checksums
(cd "${OUTPUT_DIR}" && find . -type f ! -name "checksums.sha256" -exec sha256sum {} \;) > "${OUTPUT_DIR}/checksums.sha256"

echo ""
echo "Archive exported to: ${OUTPUT_DIR}"
echo "Files: $(find "${OUTPUT_DIR}" -type f | wc -l)"
echo "Size: $(du -sh "${OUTPUT_DIR}" | cut -f1)"
echo "Checksum: $(sha256sum "${OUTPUT_DIR}/checksums.sha256" | cut -d' ' -f1 | head -c 16)..."
