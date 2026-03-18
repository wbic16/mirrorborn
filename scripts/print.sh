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
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"

mkdir -p "$LOG_DIR"

FILE=""
COPIES=1
DUPLEX=0
COLOR=0
DRY_RUN=0
CLIENT=""
PURPOSE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copies)  COPIES="$2"; shift 2 ;;
    --duplex)  DUPLEX=1; shift ;;
    --color)   COLOR=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --client)  CLIENT="$2"; shift 2 ;;
    --purpose) PURPOSE="$2"; shift 2 ;;
    --printer) PRINTER="$2"; shift 2 ;;
    -*)        echo "Unknown flag: $1"; exit 1 ;;
    *)         FILE="$1"; shift ;;
  esac
done

[[ -z "$FILE" ]] && { echo "Usage: bash print.sh <file> [--copies N] [--duplex] [--color] [--dry-run]"; exit 1; }
[[ ! -f "$FILE" ]] && { echo "Error: file not found: $FILE"; exit 1; }

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

echo ""
echo "  Audit log: ${PRINT_LOG}"
echo ""
