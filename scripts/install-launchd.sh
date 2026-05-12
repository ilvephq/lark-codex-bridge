#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOP_SCREEN="$ROOT_DIR/scripts/stop-screen.sh"
SOURCE_BRIDGE="$ROOT_DIR/bin/lark-codex-bridge"
SOURCE_HELPER="$ROOT_DIR/bin/lark-codex-bridge-appserver"

LABEL="${LARK_CODEX_LAUNCHD_LABEL:-com.ilvephq.lark-codex-bridge}"
CONFIG_DIR="${LARK_CODEX_BASE_DIR:-$HOME/.lark-codex}"
ENV_FILE="${LARK_CODEX_CREDENTIALS:-$CONFIG_DIR/.env}"
STATE_DIR="${LARK_CODEX_STATE_DIR:-$CONFIG_DIR/state}"
LOG_FILE="${LARK_CODEX_LOG_FILE:-$CONFIG_DIR/bridge.log}"

PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"

UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"
SERVICE="$DOMAIN/$LABEL"

RUNTIME_DIR="${LARK_CODEX_LAUNCHD_RUNTIME_DIR:-$CONFIG_DIR/runtime}"
RUNTIME_BIN_DIR="$RUNTIME_DIR/bin"
PROGRAM="$RUNTIME_BIN_DIR/lark-codex-bridge"
PATH_VALUE="${LARK_CODEX_LAUNCHD_PATH:-/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
THROTTLE_INTERVAL="${LARK_CODEX_LAUNCHD_THROTTLE_INTERVAL:-30}"
EXIT_TIMEOUT_SECONDS="${LARK_CODEX_LAUNCHD_EXIT_TIMEOUT_SECONDS:-30}"

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

if [[ ! -x "$SOURCE_BRIDGE" ]]; then
  echo "Missing executable: $SOURCE_BRIDGE" >&2
  exit 1
fi

if [[ ! -x "$SOURCE_HELPER" ]]; then
  echo "Missing executable: $SOURCE_HELPER" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing config: $ENV_FILE" >&2
  echo "Run scripts/install.sh first, then edit the generated .env file." >&2
  exit 1
fi

mkdir -p "$PLIST_DIR"
mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$RUNTIME_BIN_DIR"
cp "$SOURCE_BRIDGE" "$PROGRAM"
cp "$SOURCE_HELPER" "$RUNTIME_BIN_DIR/lark-codex-bridge-appserver"
chmod +x "$PROGRAM" "$RUNTIME_BIN_DIR/lark-codex-bridge-appserver"

STDOUT_PATH="$CONFIG_DIR/launchd.stdout.log"
STDERR_PATH="$CONFIG_DIR/launchd.stderr.log"

LABEL_XML="$(xml_escape "$LABEL")"
PROGRAM_XML="$(xml_escape "$PROGRAM")"
RUNTIME_DIR_XML="$(xml_escape "$RUNTIME_DIR")"
PATH_VALUE_XML="$(xml_escape "$PATH_VALUE")"
CONFIG_DIR_XML="$(xml_escape "$CONFIG_DIR")"
ENV_FILE_XML="$(xml_escape "$ENV_FILE")"
STATE_DIR_XML="$(xml_escape "$STATE_DIR")"
LOG_FILE_XML="$(xml_escape "$LOG_FILE")"
STDOUT_PATH_XML="$(xml_escape "$STDOUT_PATH")"
STDERR_PATH_XML="$(xml_escape "$STDERR_PATH")"

cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$LABEL_XML</string>

    <key>ProgramArguments</key>
    <array>
      <string>$PROGRAM_XML</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$RUNTIME_DIR_XML</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>$PATH_VALUE_XML</string>

      <key>LARK_CODEX_BASE_DIR</key>
      <string>$CONFIG_DIR_XML</string>
      <key>LARK_CODEX_CREDENTIALS</key>
      <string>$ENV_FILE_XML</string>
      <key>LARK_CODEX_STATE_DIR</key>
      <string>$STATE_DIR_XML</string>
      <key>LARK_CODEX_LOG_FILE</key>
      <string>$LOG_FILE_XML</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>$THROTTLE_INTERVAL</integer>
    <key>ExitTimeOut</key>
    <integer>$EXIT_TIMEOUT_SECONDS</integer>

    <key>StandardOutPath</key>
    <string>$STDOUT_PATH_XML</string>
    <key>StandardErrorPath</key>
    <string>$STDERR_PATH_XML</string>
  </dict>
</plist>
EOF

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$PLIST_PATH" >/dev/null
fi

if [[ -x "$STOP_SCREEN" ]]; then
  LARK_CODEX_BASE_DIR="$CONFIG_DIR" \
    LARK_CODEX_CREDENTIALS="$ENV_FILE" \
    LARK_CODEX_STATE_DIR="$STATE_DIR" \
    "$STOP_SCREEN" >/dev/null 2>&1 || true
fi

launchctl bootout "$DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl enable "$SERVICE" >/dev/null 2>&1 || true
launchctl kickstart -k "$SERVICE" >/dev/null 2>&1 || true

echo "Installed LaunchAgent: $PLIST_PATH"
echo "Service: $SERVICE"
echo "Logs: $LOG_FILE"
