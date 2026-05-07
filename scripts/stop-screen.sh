#!/usr/bin/env bash
set -euo pipefail

SCREEN_NAME="${LARK_CODEX_SCREEN_NAME:-lark-codex}"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
STATE_DIR="${LARK_CODEX_STATE_DIR:-$CONFIG_DIR/state}"
BRIDGE_LOCK_DIR="$STATE_DIR/bridge.lock"
BRIDGE_LOCK_PID_FILE="$BRIDGE_LOCK_DIR/pid"

if (screen -ls 2>/dev/null || true) | grep -q "[.]$SCREEN_NAME[[:space:]]"; then
  screen -S "$SCREEN_NAME" -X quit
  echo "Stopped screen session: $SCREEN_NAME"
else
  echo "Screen session is not running: $SCREEN_NAME"
fi

# On macOS, `screen -X quit` can occasionally leave the launched command running
# (e.g. via `login -pflq ...`). Use the bridge pidfile as a source of truth.
if [[ -f "$BRIDGE_LOCK_PID_FILE" ]]; then
  pid=""
  read -r pid <"$BRIDGE_LOCK_PID_FILE" 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ -n "$cmd" && "$cmd" == *"lark-codex-bridge/bin/lark-codex-bridge"* ]]; then
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        sleep 1
      fi
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
      echo "Stopped bridge process: $pid"
    else
      echo "Bridge pidfile exists, but command mismatch; not killing pid=$pid"
    fi
  fi
fi
