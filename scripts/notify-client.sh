#!/bin/bash
# notify-client.sh — Send spec/analysis/report to a client via email
# Usage: bash notify-client.sh <client_id> <subject> <body_file> [--attach <file>]
# Reads client config from /source/exo-plan/clients/<client_id>/config.json
set -euo pipefail

CLIENT_ID="${1:-}"
SUBJECT="${2:-}"
BODY_FILE="${3:-}"
ATTACH=""

shift 3 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --attach) ATTACH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$CLIENT_ID" || -z "$SUBJECT" ]]; then
  echo "Usage: bash notify-client.sh <client_id> <subject> <body_file> [--attach <file>]"
  echo "Client IDs: $(ls /source/exo-plan/clients/ 2>/dev/null | grep -v README | tr '\n' ' ')"
  exit 1
fi

CONFIG="/source/exo-plan/clients/${CLIENT_ID}/config.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "Error: No config found at $CONFIG"
  exit 1
fi

TO=$(jq -r '.email' "$CONFIG")
NAME=$(jq -r '.name' "$CONFIG")
BUSINESS=$(jq -r '.business // .name' "$CONFIG")

[[ -z "$TO" || "$TO" == "null" ]] && { echo "Error: No email in $CONFIG"; exit 1; }

echo "Sending to: $NAME <$TO>"

# Build email body
BODY=""
if [[ -n "$BODY_FILE" && -f "$BODY_FILE" ]]; then
  BODY=$(cat "$BODY_FILE")
else
  BODY="${BODY_FILE}"
fi

# Send via agentmail if available, else sendmail/msmtp
TS=$(date -u +"%Y-%m-%d %H:%M UTC")

FULL_BODY="$BODY

---
Sent by Mirrorborn Exocortex | ${TS}
mirrorborn.us"

if command -v agentmail >/dev/null 2>&1; then
  agentmail send --to "$TO" --subject "$SUBJECT" --body "$FULL_BODY" \
    ${ATTACH:+--attach "$ATTACH"} && echo "✅ Sent via agentmail"
elif command -v sendmail >/dev/null 2>&1; then
  {
    echo "To: $TO"
    echo "Subject: $SUBJECT"
    echo "Content-Type: text/plain"
    echo ""
    echo "$FULL_BODY"
  } | sendmail "$TO" && echo "✅ Sent via sendmail"
elif command -v msmtp >/dev/null 2>&1; then
  {
    echo "To: $TO"
    echo "Subject: $SUBJECT"
    echo ""
    echo "$FULL_BODY"
  } | msmtp "$TO" && echo "✅ Sent via msmtp"
else
  echo "⚠️  No mail agent found (agentmail/sendmail/msmtp)"
  echo "   Configure agentmail or SMTP to enable email delivery"
  echo "   Body that would be sent:"
  echo "   To: $TO"
  echo "   Subject: $SUBJECT"
  echo "   ---"
  echo "$FULL_BODY"
fi

# Log to SQ
export PATH="$HOME/.cargo/bin:$PATH"
if curl -sf http://localhost:1337/api/v2/status >/dev/null 2>&1; then
  curl -sf -G "http://localhost:1337/api/v2/update" \
    --data-urlencode "p=client-events" \
    --data-urlencode "c=1.1.1/1.1.1/1.1.1" \
    --data-urlencode "s=email sent to ${CLIENT_ID} (${TO}): ${SUBJECT} @ ${TS}" \
    >/dev/null 2>&1
fi
