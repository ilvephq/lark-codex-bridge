#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
ENV_FILE="${LARK_CODEX_CREDENTIALS:-$CONFIG_DIR/.env}"

required_commands=(bash jq curl sqlite3 lark-cli codex screen)
missing=()

for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "Missing required commands: ${missing[*]}" >&2
  echo "Install them first, then rerun scripts/install.sh." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"

if [[ -f "$ENV_FILE" ]]; then
  echo "Config already exists: $ENV_FILE"
else
  cp "$ROOT_DIR/config.example.env" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Created config template: $ENV_FILE"
fi

chmod +x "$ROOT_DIR/bin/lark-codex-bridge" "$ROOT_DIR/scripts/start-screen.sh" "$ROOT_DIR/scripts/stop-screen.sh"

echo
echo "Next steps:"
echo "1. Edit $ENV_FILE and fill in your Feishu/Lark app credentials and allowed sender open_id."
echo "2. Start the bridge: $ROOT_DIR/scripts/start-screen.sh"
echo "3. Send 'status' to your Feishu/Lark bot."
