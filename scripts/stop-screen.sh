#!/usr/bin/env bash
set -euo pipefail

SCREEN_NAME="${LARK_CODEX_SCREEN_NAME:-lark-codex}"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
ENV_FILE="${LARK_CODEX_CREDENTIALS:-$CONFIG_DIR/.env}"
STATE_DIR="${LARK_CODEX_STATE_DIR:-$CONFIG_DIR/state}"
BRIDGE_LOCK_DIR="$STATE_DIR/bridge.lock"
BRIDGE_LOCK_PID_FILE="$BRIDGE_LOCK_DIR/pid"

if (screen -ls 2>/dev/null || true) | grep -q "[.]$SCREEN_NAME[[:space:]]"; then
  screen -S "$SCREEN_NAME" -X quit
  echo "Stopped screen session: $SCREEN_NAME"
else
  echo "Screen session is not running: $SCREEN_NAME"
fi

# `lark-cli event +subscribe` enforces a single-instance lock per App ID. When `screen`
# quits, macOS can occasionally leave the spawned `lark-cli` subscriber alive, which
# keeps the lock held and makes the next bridge start look "hung" (no events).
#
# Clean up any remaining subscriber holding the lock for this app.
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE" 2>/dev/null || true
fi
APP_ID="${LARKSUITE_CLI_APP_ID:-${FEISHU_APP_ID:-}}"
SUBSCRIBE_LOCK_FILE="$HOME/.lark-cli/locks/subscribe_${APP_ID}.lock"
if [[ -n "$APP_ID" && -f "$SUBSCRIBE_LOCK_FILE" && -x "$(command -v lsof)" ]]; then
  pids="$(lsof -t "$SUBSCRIBE_LOCK_FILE" 2>/dev/null | tr '\n' ' ' | xargs || true)"
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      kill "$pid" 2>/dev/null || true
    done
    sleep 1
    for pid in $pids; do
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    done
    echo "Stopped lark subscriber(s) holding subscribe lock: $pids"
  fi
  # If no process holds it, it's a stale file; remove it.
  if ! lsof "$SUBSCRIBE_LOCK_FILE" >/dev/null 2>&1; then
    rm -f "$SUBSCRIBE_LOCK_FILE" 2>/dev/null || true
  fi
fi

# On macOS, `screen -X quit` can occasionally leave the launched command running
# (e.g. via `login -pflq ...`). Use the bridge pidfile as a source of truth.
if [[ -f "$BRIDGE_LOCK_PID_FILE" ]]; then
  pid=""
  read -r pid <"$BRIDGE_LOCK_PID_FILE" 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ -n "$cmd" && ( "$cmd" == *"lark-codex-bridge/bin/lark-codex-bridge"* || "$cmd" == *"lark-codex-bridge/bin/lark-codex-bridge-appserver"* ) ]]; then
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
