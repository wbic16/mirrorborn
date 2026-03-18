#!/bin/bash
# print-report.sh — Audited print workflow for Ranch LAN printer
# Confirms page count, prompts for approval, prints to Canon MF650C
# Usage: bash print-report.sh <file> [--client <client_id>] [--copies <n>] [--yes]
#
# Supported formats: PDF, HTML, Markdown (.md), plain text
# Printer: canon-mf650c @ 192.168.86.181 (Ranch LAN)
set -euo pipefail

FILE="${1:-}"
CLIENT_ID=""
COPIES=1
AUTO_APPROVE=0
FORCE=0
PRINTER="${PRINTER:-canon-mf650c}"
PRINTER_IP="192.168.86.181"
SELF_NAME="$(jq -r '.name' /etc/mirrorborn/identity.json 2>/dev/null || hostname -s)"
SELF_HOST="$(hostname -s)"

shift 1 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)  CLIENT_ID="$2"; shift 2 ;;
    --copies)  COPIES="$2"; shift 2 ;;
    --yes|-y)  AUTO_APPROVE=1; shift ;;
    --force)   FORCE=1; shift ;;
    --printer) PRINTER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Usage: bash print-report.sh <file> [--client <id>] [--copies <n>] [--yes]"
  echo "Supported: .pdf .html .md .txt"
  exit 1
fi

[[ ! -f "$FILE" ]] && { echo "Error: File not found: $FILE"; exit 1; }

# ── Check printer reachability ─────────────────────────────────────────────
if ! curl -sf --connect-timeout 3 "http://${PRINTER_IP}:80/" >/dev/null 2>&1; then
  echo "❌ Printer unreachable at http://${PRINTER_IP}"
  echo "   Is the Canon MF650C on and connected to the LAN?"
  exit 1
fi

# ── Convert to PDF if needed ──────────────────────────────────────────────
EXT="${FILE##*.}"
PRINT_FILE="$FILE"
TMPFILE=""

if [[ "$EXT" == "md" || "$EXT" == "txt" ]]; then
  TMPFILE="/tmp/print-$(date +%s).pdf"
  if command -v weasyprint >/dev/null 2>&1; then
    # Convert MD → HTML → PDF
    python3 -c "
import sys, subprocess, tempfile, os
md = open('$FILE').read()
# Simple MD to HTML
html = '<html><body><pre style=\"font-family: serif; white-space: pre-wrap; margin: 2cm;\">' + md.replace('<','&lt;').replace('>','&gt;') + '</pre></body></html>'
tmp = tempfile.mktemp(suffix='.html')
open(tmp, 'w').write(html)
subprocess.run(['weasyprint', tmp, '$TMPFILE'], check=True)
os.unlink(tmp)
"
    PRINT_FILE="$TMPFILE"
  elif command -v pandoc >/dev/null 2>&1; then
    pandoc "$FILE" -o "$TMPFILE" --pdf-engine=wkhtmltopdf 2>/dev/null || \
    pandoc "$FILE" -o "$TMPFILE" 2>/dev/null
    PRINT_FILE="$TMPFILE"
  else
    echo "⚠️  No PDF converter (weasyprint/pandoc). Printing as plain text."
    PRINT_FILE="$FILE"
  fi
elif [[ "$EXT" == "html" ]]; then
  TMPFILE="/tmp/print-$(date +%s).pdf"
  if command -v weasyprint >/dev/null 2>&1; then
    weasyprint "$FILE" "$TMPFILE" 2>/dev/null && PRINT_FILE="$TMPFILE"
  elif command -v wkhtmltopdf >/dev/null 2>&1; then
    wkhtmltopdf "$FILE" "$TMPFILE" 2>/dev/null && PRINT_FILE="$TMPFILE"
  fi
fi

# ── Count pages ────────────────────────────────────────────────────────────
PAGE_COUNT="?"
if [[ "$PRINT_FILE" == *.pdf ]] && command -v pdfinfo >/dev/null 2>&1; then
  PAGE_COUNT=$(pdfinfo "$PRINT_FILE" 2>/dev/null | grep "^Pages:" | awk '{print $2}' || echo "?")
elif [[ "$PRINT_FILE" == *.pdf ]]; then
  PAGE_COUNT=$(python3 -c "
try:
    data = open('$PRINT_FILE', 'rb').read()
    import re
    pages = len(re.findall(b'/Type\s*/Page[^s]', data))
    print(pages if pages > 0 else '?')
except:
    print('?')
" 2>/dev/null || echo "?")
fi

TOTAL_PAGES="?"
if [[ "$PAGE_COUNT" =~ ^[0-9]+$ && "$COPIES" =~ ^[0-9]+$ ]]; then
  TOTAL_PAGES=$(( PAGE_COUNT * COPIES ))
fi

# ── Audit summary ─────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║          PRINT JOB AUDIT                     ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
printf "  %-16s %s\n" "File:" "$(basename "$FILE")"
printf "  %-16s %s\n" "Format:" "$EXT → $(basename "$PRINT_FILE" | grep -oP '\.\w+$' || echo $EXT)"
printf "  %-16s %s\n" "Pages:" "${PAGE_COUNT} (× ${COPIES} copies = ${TOTAL_PAGES} total)"
printf "  %-16s %s\n" "Printer:" "$PRINTER"
printf "  %-16s %s\n" "Printer IP:" "$PRINTER_IP"
[[ -n "$CLIENT_ID" ]] && printf "  %-16s %s\n" "Client:" "$CLIENT_ID"
echo ""

# ── Approval gate ─────────────────────────────────────────────────────────
if [[ "$AUTO_APPROVE" == "0" ]]; then
  read -r -p "  Print ${TOTAL_PAGES} page(s) to ${PRINTER}? [y/N] " CONFIRM
  [[ "${CONFIRM,,}" != "y" ]] && { echo "  Cancelled."; [[ -n "$TMPFILE" ]] && rm -f "$TMPFILE"; exit 0; }
fi

# ── Compute file hash ─────────────────────────────────────────────────────
FILE_HASH=$(sha256sum "$PRINT_FILE" | awk '{print $1}')
JOB_HASH="${FILE_HASH:0:16}"

# ── Acquire print lock + dedup check ─────────────────────────────────────
LOCK_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/../workspace/skills/print/scripts/print-lock.sh"
[[ ! -f "$LOCK_SCRIPT" ]] && LOCK_SCRIPT="/home/wbic16/.openclaw/workspace/skills/print/scripts/print-lock.sh"

if [[ -f "$LOCK_SCRIPT" ]]; then
  source "$LOCK_SCRIPT"
  [[ "$FORCE" == "0" ]] && check_print_dedup "$FILE_HASH"
  acquire_print_lock "$SELF_NAME" "$SELF_HOST" "$JOB_HASH"
  LOCK_ACQUIRED=1
else
  echo "  ⚠️  Lock script not found — proceeding without mutex"
  LOCK_ACQUIRED=0
fi

# ── Print ─────────────────────────────────────────────────────────────────
echo ""
echo "  Sending to printer..."
JOB_ID=$(lp -d "$PRINTER" -n "$COPIES" "$PRINT_FILE" 2>&1 | grep -oP 'request id is \K\S+' || echo "unknown")
echo "  ✅ Job submitted: $JOB_ID"

# Release lock + record dedup hash
if [[ "${LOCK_ACQUIRED:-0}" == "1" ]]; then
  record_print_job_hash "$FILE_HASH" "$SELF_NAME"
  release_print_lock
fi

# ── Log to SQ ─────────────────────────────────────────────────────────────
export PATH="$HOME/.cargo/bin:$PATH"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_MSG="print job: $(basename "$FILE") | pages:${PAGE_COUNT} | copies:${COPIES} | total:${TOTAL_PAGES} | job:${JOB_ID} | printer:${PRINTER} | ts:${TS}"
[[ -n "$CLIENT_ID" ]] && LOG_MSG="$LOG_MSG | client:${CLIENT_ID}"

if curl -sf http://localhost:1337/api/v2/status >/dev/null 2>&1; then
  curl -sf -G "http://localhost:1337/api/v2/update" \
    --data-urlencode "p=print-jobs" \
    --data-urlencode "c=1.1.1/1.1.1/1.1.1" \
    --data-urlencode "s=${LOG_MSG}" >/dev/null 2>&1
  echo "  Logged to SQ: print-jobs/1.1.1/1.1.1/1.1.1"
fi

# ── Monitor job ───────────────────────────────────────────────────────────
echo ""
echo "  Job status (watching 10s):"
for i in {1..5}; do
  sleep 2
  STATUS=$(lpstat -W completed 2>/dev/null | grep "${JOB_ID%%[^0-9]*}" | head -1 || \
           lpq -P "$PRINTER" 2>/dev/null | head -3)
  [[ -n "$STATUS" ]] && echo "    $STATUS" && break
  echo "    ⏳ waiting..."
done

[[ -n "$TMPFILE" ]] && rm -f "$TMPFILE"
echo ""
echo "  Done. Check the printer at http://${PRINTER_IP}"
