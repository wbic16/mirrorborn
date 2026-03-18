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
# Distributed lock via SQ on elven-path (global across all ranch nodes)
SQ_MASTER="http://elven-path.local:1337"
LOCK_PHEXT="print-lock"
LOCK_COORD="1.1.1/1.1.1/1.1.1"
DEDUP_COORD="1.1.1/1.1.1/2.1.1"
LOCK_TTL=120        # seconds — stale lock timeout (job shouldn't take >2 min)
DEDUP_WINDOW=300    # 5-minute dedup window
LOCK_RETRY=3        # re-read attempts after claiming to detect races
LOCK_RETRY_WAIT=1   # seconds between retries
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EPOCH="$(date +%s)"
NODE_NAME="$(jq -r '.name' "${STATE_DIR}/identity.json" 2>/dev/null || hostname -s)"

mkdir -p "$LOG_DIR"

# ── SQ lock helpers ───────────────────────────────────────────────────────────
sq_read() {
  local phext="$1" coord="$2"
  curl -sf --max-time 3 "${SQ_MASTER}/api/v2/select?p=${phext}&c=${coord}" 2>/dev/null || echo ""
}
sq_write() {
  local phext="$1" coord="$2" value="$3"
  local encoded; encoded="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$value" 2>/dev/null)"
  curl -sf --max-time 3 "${SQ_MASTER}/api/v2/update?p=${phext}&c=${coord}&s=${encoded}" >/dev/null 2>&1
}
sq_clear() {
  local phext="$1" coord="$2"
  curl -sf --max-time 3 "${SQ_MASTER}/api/v2/update?p=${phext}&c=${coord}&s=" >/dev/null 2>&1
}

sq_lock_acquire() {
  # Check existing lock
  local current; current="$(sq_read "$LOCK_PHEXT" "$LOCK_COORD")"
  if [[ -n "$current" ]]; then
    local lock_epoch; lock_epoch="$(echo "$current" | cut -d: -f3)"
    local now_epoch; now_epoch="$(date +%s)"
    local age=$(( now_epoch - lock_epoch ))
    if [[ "$age" -lt "$LOCK_TTL" ]]; then
      local holder; holder="$(echo "$current" | cut -d: -f2)"
      echo "LOCKED_BY:${holder}:age=${age}s"
      return 1
    else
      echo "STALE lock from $(echo "$current" | cut -d: -f2) (${age}s old) — clearing" >&2
      sq_clear "$LOCK_PHEXT" "$LOCK_COORD"
    fi
  fi

  # Claim the lock
  local claim="LOCKED:${NODE_NAME}:${EPOCH}:${FILE_HASH:0:16}"
  sq_write "$LOCK_PHEXT" "$LOCK_COORD" "$claim"

  # Re-read LOCK_RETRY times to detect concurrent claims (check-then-act race)
  sleep "$LOCK_RETRY_WAIT"
  local i
  for i in $(seq 1 $LOCK_RETRY); do
    local readback; readback="$(sq_read "$LOCK_PHEXT" "$LOCK_COORD")"
    if [[ "$readback" != "$claim" ]]; then
      # Another node won the race
      local winner; winner="$(echo "$readback" | cut -d: -f2)"
      echo "RACE_LOST:${winner}"
      return 1
    fi
    [[ "$i" -lt "$LOCK_RETRY" ]] && sleep "$LOCK_RETRY_WAIT"
  done
  return 0
}

sq_lock_release() {
  # Only release if we own the lock
  local current; current="$(sq_read "$LOCK_PHEXT" "$LOCK_COORD")"
  if echo "$current" | grep -q "LOCKED:${NODE_NAME}:"; then
    sq_clear "$LOCK_PHEXT" "$LOCK_COORD"
  fi
}

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

# ── File hash (used for both dedup and lock identity) ─────────────────────────
FILE_HASH="$(sha256sum "$FILE" | awk '{print $1}')"
JOB_KEY="${FILE_HASH:0:16}:${COPIES}:${DUPLEX}:${COLOR}"

# ── Global Deduplication Check via SQ ────────────────────────────────────────
if [[ "$FORCE" == "0" && "$DRY_RUN" == "0" ]]; then
  DEDUP_ENTRY="$(sq_read "$LOCK_PHEXT" "$DEDUP_COORD")"
  if [[ -n "$DEDUP_ENTRY" ]]; then
    DEDUP_KEY="$(echo "$DEDUP_ENTRY" | cut -d: -f1)"
    DEDUP_EPOCH="$(echo "$DEDUP_ENTRY" | cut -d: -f2)"
    DEDUP_NODE="$(echo "$DEDUP_ENTRY" | cut -d: -f3)"
    ELAPSED=$(( EPOCH - DEDUP_EPOCH ))
    if [[ "$DEDUP_KEY" == "$JOB_KEY" && "$ELAPSED" -lt "$DEDUP_WINDOW" ]]; then
      REMAINING=$(( DEDUP_WINDOW - ELAPSED ))
      echo ""
      echo "  ⚠ DUPLICATE DETECTED: This exact job was printed ${ELAPSED}s ago by ${DEDUP_NODE}."
      echo "    Cooldown: ${REMAINING}s remaining (${DEDUP_WINDOW}s window)."
      echo "    Use --force to override."
      echo ""
      echo "[${TS}] DEDUP_BLOCKED: $(basename "$FILE") job=${JOB_KEY} elapsed=${ELAPSED}s node=${NODE_NAME} original=${DEDUP_NODE}" >> "$PRINT_LOG"
      exit 1
    fi
  fi
fi

# ── Global Exclusive Lock via SQ ─────────────────────────────────────────────
if [[ "$DRY_RUN" == "0" ]]; then
  # Check SQ master is reachable
  if ! curl -sf --max-time 3 "${SQ_MASTER}/api/v2/status" >/dev/null 2>&1; then
    echo "  ⚠ SQ master unreachable (${SQ_MASTER}) — cannot acquire global print lock."
    echo "  Printing blocked to prevent duplicate jobs. Check elven-path SQ."
    echo "[${TS}] LOCK_ERROR: SQ master unreachable for $(basename "$FILE") on ${NODE_NAME}" >> "$PRINT_LOG"
    exit 1
  fi

  LOCK_RESULT="$(sq_lock_acquire)"
  LOCK_EXIT=$?
  if [[ "$LOCK_EXIT" -ne 0 ]]; then
    case "${LOCK_RESULT%%:*}" in
      LOCKED_BY)
        HOLDER="${LOCK_RESULT#LOCKED_BY:}"
        echo ""
        echo "  ⚠ PRINT LOCKED: ${HOLDER}"
        echo "    Another node is currently printing. Try again shortly."
        echo ""
        echo "[${TS}] LOCK_BLOCKED: $(basename "$FILE") by ${NODE_NAME} — held by ${HOLDER}" >> "$PRINT_LOG"
        ;;
      RACE_LOST)
        WINNER="${LOCK_RESULT#RACE_LOST:}"
        echo ""
        echo "  ⚠ LOCK RACE: ${WINNER} claimed the printer first."
        echo "    Try again after their job completes."
        echo ""
        echo "[${TS}] RACE_LOST: $(basename "$FILE") by ${NODE_NAME} — won by ${WINNER}" >> "$PRINT_LOG"
        ;;
    esac
    exit 1
  fi
  # Release lock on exit (success or failure)
  trap 'sq_lock_release' EXIT
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

# ── Record in global dedup store via SQ ──────────────────────────────────────
DEDUP_RECORD="${JOB_KEY}:${EPOCH}:${NODE_NAME}"
sq_write "$LOCK_PHEXT" "$DEDUP_COORD" "$DEDUP_RECORD"

echo ""
echo "  Audit log: ${PRINT_LOG}"
echo ""
