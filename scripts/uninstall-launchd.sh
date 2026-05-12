#!/usr/bin/env bash
set -euo pipefail

LABEL="${LARK_CODEX_LAUNCHD_LABEL:-com.ilvephq.lark-codex-bridge}"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"
SERVICE="$DOMAIN/$LABEL"

if [[ -f "$PLIST_PATH" ]]; then
  launchctl bootout "$DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Removed LaunchAgent: $PLIST_PATH"
else
  echo "LaunchAgent not found: $PLIST_PATH"
fi

launchctl disable "$SERVICE" >/dev/null 2>&1 || true
echo "Service: $SERVICE"
