#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREEN_NAME="${LARK_CODEX_SCREEN_NAME:-lark-codex}"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
ENV_FILE="${LARK_CODEX_CREDENTIALS:-$CONFIG_DIR/.env}"
STATE_DIR="${LARK_CODEX_STATE_DIR:-$CONFIG_DIR/state}"
BRIDGE_LOCK_DIR="$STATE_DIR/bridge.lock"
BRIDGE_LOCK_PID_FILE="$BRIDGE_LOCK_DIR/pid"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing config: $ENV_FILE" >&2
  echo "Run scripts/install.sh first, then edit the generated .env file." >&2
  exit 1
fi

if [[ -f "$BRIDGE_LOCK_PID_FILE" ]]; then
  pid=""
  read -r pid <"$BRIDGE_LOCK_PID_FILE" 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Bridge already running (pid=$pid)."
    exit 0
  fi
  # Stale lock: clear and proceed.
  rm -f "$BRIDGE_LOCK_PID_FILE" 2>/dev/null || true
  rmdir "$BRIDGE_LOCK_DIR" 2>/dev/null || true
fi

if (screen -ls 2>/dev/null || true) | grep -q "[.]$SCREEN_NAME[[:space:]]"; then
  echo "Screen session already running: $SCREEN_NAME"
  exit 0
fi

screen -dmS "$SCREEN_NAME" "$ROOT_DIR/bin/lark-codex-bridge"
echo "Started screen session: $SCREEN_NAME"
echo "View logs: tail -f ${LARK_CODEX_LOG_FILE:-$CONFIG_DIR/bridge.log}"
