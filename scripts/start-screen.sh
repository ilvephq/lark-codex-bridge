#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREEN_NAME="${LARK_CODEX_SCREEN_NAME:-lark-codex}"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
ENV_FILE="${LARK_CODEX_CREDENTIALS:-$CONFIG_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing config: $ENV_FILE" >&2
  echo "Run scripts/install.sh first, then edit the generated .env file." >&2
  exit 1
fi

if screen -ls | grep -q "[.]$SCREEN_NAME[[:space:]]"; then
  echo "Screen session already running: $SCREEN_NAME"
  exit 0
fi

screen -dmS "$SCREEN_NAME" "$ROOT_DIR/bin/lark-codex-bridge"
echo "Started screen session: $SCREEN_NAME"
echo "View logs: tail -f ${LARK_CODEX_LOG_FILE:-$CONFIG_DIR/bridge.log}"
