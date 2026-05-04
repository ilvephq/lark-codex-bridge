#!/usr/bin/env bash
set -euo pipefail

SCREEN_NAME="${LARK_CODEX_SCREEN_NAME:-lark-codex}"

if screen -ls | grep -q "[.]$SCREEN_NAME[[:space:]]"; then
  screen -S "$SCREEN_NAME" -X quit
  echo "Stopped screen session: $SCREEN_NAME"
else
  echo "Screen session is not running: $SCREEN_NAME"
fi
