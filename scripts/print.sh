#!/bin/bash
# print.sh — Audited print workflow for Ranch Canon MF650C
# Confirms page count, prompts for approval, logs every print job
# Usage: bash print.sh <file> [--copies N] [--duplex] [--color] [--dry-run]
#
# Printer: Canon MF650C Series at 192.168.86.181
# CUPS name: canon-mf650c

set -euo pipefail

STATE_DIR="/etc/mirrorborn"
LOG_DIR="/var/log/mirrorborn"
PRINTER="canon-mf650c"
PRINT_LOG="${LOG_DIR}/print-jobs.log"
LOCK_FILE="/var/lock/mirrorborn-print.lock"
DEDUP_FILE="${LOG_DIR}/print-dedup.json"
DEDUP_WINDOW=300  # 5 minutes in seconds
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EPOCH="$(date +%s)"
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"

mkdir -p "$LOG_DIR"
sudo touch "$LOCK_FILE" 2>/dev/null || touch "$LOCK_FILE" 2>/dev/null || true

FILE=""
COPIES=1
DUPLEX=0
COLOR=0
DRY_RUN=0
CLIENT=""
PURPOSE=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copies)  COPIES="$2"; shift 2 ;;
    --duplex)  DUPLEX=1; shift ;;
    --color)   COLOR=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --client)  CLIENT="$2"; shift 2 ;;
    --purpose) PURPOSE="$2"; shift 2 ;;
    --printer) PRINTER="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -*)        echo "Unknown flag: $1"; exit 1 ;;
    *)         FILE="$1"; shift ;;
  esac
done

[[ -z "$FILE" ]] && { echo "Usage: bash print.sh <file> [--copies N] [--duplex] [--color] [--dry-run] [--force]"; exit 1; }
[[ ! -f "$FILE" ]] && { echo "Error: file not found: $FILE"; exit 1; }

# ── Deduplication Check (5-minute window) ────────────────────────────────────
FILE_HASH="$(sha256sum "$FILE" | awk '{print $1}')"
JOB_KEY="${FILE_HASH}:${COPIES}:${DUPLEX}:${COLOR}"

if [[ "$FORCE" == "0" && "$DRY_RUN" == "0" && -f "$DEDUP_FILE" ]]; then
  LAST_EPOCH="$(python3 -c "
import json
try:
    d = json.load(open('${DEDUP_FILE}'))
    print(d.get('${JOB_KEY}', 0))
except:
    print(0)
" 2>/dev/null || echo 0)"
  ELAPSED=$(( EPOCH - LAST_EPOCH ))
  if [[ "$LAST_EPOCH" -gt 0 && "$ELAPSED" -lt "$DEDUP_WINDOW" ]]; then
    REMAINING=$(( DEDUP_WINDOW - ELAPSED ))
    echo ""
    echo "  ⚠ DUPLICATE DETECTED: This exact job was printed ${ELAPSED}s ago."
    echo "    Cooldown: ${REMAINING}s remaining (${DEDUP_WINDOW}s window)."
    echo "    Use --force to override."
    echo ""
    echo "[${TS}] DEDUP_BLOCKED: $(basename "$FILE") (job_key=${JOB_KEY:0:16}...) elapsed=${ELAPSED}s node=${NODE_NAME}" >> "$PRINT_LOG"
    exit 1
  fi
fi

# ── Exclusive Lock (one agent prints at a time) ───────────────────────────────
# Uses flock on LOCK_FILE — non-blocking, fails immediately if locked
if [[ "$DRY_RUN" == "0" ]]; then
  exec 9>"$LOCK_FILE"
  if ! flock --nonblock 9; then
    LOCK_HOLDER="$(cat "${LOCK_FILE}.owner" 2>/dev/null || echo "unknown")"
    echo ""
    echo "  ⚠ PRINT LOCKED: Another agent is currently printing."
    echo "    Lock holder: ${LOCK_HOLDER}"
    echo "    Try again in a moment."
    echo ""
    echo "[${TS}] LOCK_BLOCKED: $(basename "$FILE") by ${NODE_NAME} (holder: ${LOCK_HOLDER})" >> "$PRINT_LOG"
    exit 1
  fi
  # Write lock owner info
  echo "${NODE_NAME} @ ${TS}" > "${LOCK_FILE}.owner"
  # Lock is held for duration of script via fd 9; released on exit
  trap 'rm -f "${LOCK_FILE}.owner"' EXIT
fi

# ── Page Count ──────────────────────────────────────────────────────────────

count_pages() {
  local f="$1"
  local ext="${f##*.}"
  case "$ext" in
    pdf|PDF)
      if command -v pdfinfo >/dev/null 2>&1; then
        pdfinfo "$f" 2>/dev/null | grep -i "^Pages:" | awk '{print $2}' || echo "?"
      elif command -v pdftk >/dev/null 2>&1; then
        pdftk "$f" dump_data 2>/dev/null | grep NumberOfPages | awk '{print $2}' || echo "?"
      else
        echo "?"
      fi
      ;;
    txt|md|html)
      # Estimate: ~50 lines per page
      local lines; lines=$(wc -l < "$f")
      echo "~$((lines / 50 + 1)) (estimated)"
      ;;
    *)
      echo "? (unknown format)"
      ;;
  esac
}

FILE_SIZE="$(du -h "$FILE" | awk '{print $1}')"
FILE_NAME="$(basename "$FILE")"
PAGES="$(count_pages "$FILE")"
PAGE_NUM="$(echo "$PAGES" | grep -oE '^[~]?[0-9]+' | tr -d '~')"
PAGE_NUM="${PAGE_NUM:-1}"
TOTAL_SHEETS=$(( COPIES * PAGE_NUM ))
[[ "$DUPLEX" == "1" ]] && TOTAL_SHEETS=$(( (TOTAL_SHEETS + 1) / 2 ))

# ── Audit Summary ────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              PRINT JOB CONFIRMATION                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  File:     ${FILE_NAME} (${FILE_SIZE})"
echo "  Pages:    ${PAGES}"
echo "  Copies:   ${COPIES}"
echo "  Duplex:   $([ "$DUPLEX" == "1" ] && echo "Yes (double-sided)" || echo "No (single-sided)")"
echo "  Color:    $([ "$COLOR" == "1" ] && echo "Yes" || echo "No (grayscale)")"
echo "  Printer:  ${PRINTER} (Canon MF650C @ 192.168.86.181)"
echo "  Sheets:   ~${TOTAL_SHEETS} sheet(s) of paper"
[[ -n "$CLIENT" ]] && echo "  Client:   ${CLIENT}"
[[ -n "$PURPOSE" ]] && echo "  Purpose:  ${PURPOSE}"
echo ""

if [[ "$DRY_RUN" == "1" ]]; then
  echo "  [DRY RUN — no job sent]"
  echo ""
  exit 0
fi

# ── Confirmation ─────────────────────────────────────────────────────────────

read -r -p "  Print this job? [y/N]: " confirm
echo ""

if [[ "${confirm,,}" != "y" && "${confirm,,}" != "yes" ]]; then
  echo "  Job cancelled."
  echo "[${TS}] CANCELLED: ${FILE_NAME} (${PAGES}pp × ${COPIES}) by ${NODE_NAME}" >> "$PRINT_LOG"
  exit 0
fi

# ── Build lp options ─────────────────────────────────────────────────────────

LP_OPTS=(-d "$PRINTER" -n "$COPIES")
[[ "$DUPLEX" == "1" ]] && LP_OPTS+=(-o "sides=two-sided-long-edge")
[[ "$COLOR" == "0" ]] && LP_OPTS+=(-o "ColorModel=Gray")
[[ -n "$CLIENT" ]] && LP_OPTS+=(-t "${CLIENT}: ${FILE_NAME}")

# ── Send Job ─────────────────────────────────────────────────────────────────

JOB_ID="$(lp "${LP_OPTS[@]}" "$FILE" 2>&1 | grep -oP 'job \K[0-9]+'  || echo "unknown")"

if [[ "$JOB_ID" != "unknown" ]]; then
  echo "  ✓ Job submitted: #${JOB_ID}"
  echo "  Monitor: lpstat -W completed -p ${PRINTER}"
else
  echo "  ⚠ Job sent but ID not captured. Check: lpstat -p ${PRINTER}"
fi

# ── Audit Log ────────────────────────────────────────────────────────────────

AUDIT_LINE="[${TS}] PRINTED: ${FILE_NAME} | pages=${PAGES} copies=${COPIES} duplex=${DUPLEX} color=${COLOR} | job=${JOB_ID} | printer=${PRINTER} | node=${NODE_NAME}$([ -n "$CLIENT" ] && echo " | client=${CLIENT}" || echo "")$([ -n "$PURPOSE" ] && echo " | purpose=${PURPOSE}" || echo "")"
echo "$AUDIT_LINE" >> "$PRINT_LOG"

# ── Record in dedup store ─────────────────────────────────────────────────────
python3 - << PYEOF
import json
try:
    d = json.load(open('${DEDUP_FILE}'))
except:
    d = {}
# Prune entries older than dedup window to keep file small
now = ${EPOCH}
d = {k: v for k, v in d.items() if now - v < ${DEDUP_WINDOW} * 2}
d['${JOB_KEY}'] = now
with open('${DEDUP_FILE}', 'w') as f:
    json.dump(d, f)
PYEOF

echo ""
echo "  Audit log: ${PRINT_LOG}"
echo ""
