#!/usr/bin/env bash
# Shared settings and helpers for the FloatPlayer scripts. Source this file, don't run it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="FloatPlayer"
BUNDLE_ID="com.ahmetinho.floatplayer"
VERSION="0.1.0"
MIN_MACOS="14.0"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' bulunamadı (xcode-select --install?)"
}

app_running() {
  pgrep -x "$APP_NAME" >/dev/null 2>&1
}

# Asks the app to quit so it can save its state, then force-kills if it hangs.
quit_app() {
  app_running || return 0
  log "$APP_NAME kapatılıyor"
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    app_running || return 0
    sleep 0.25
  done
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
}
