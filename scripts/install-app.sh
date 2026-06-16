#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Shotter"
BUILT_APP="$PROJECT_DIR/.build/$APP_NAME.app"
INSTALL_DIR="${SHOTTER_INSTALL_DIR:-/Applications}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

cd "$PROJECT_DIR"
"$SCRIPT_DIR/build-app.sh"

osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
open "$INSTALLED_APP"

echo "Installed and opened $INSTALLED_APP"
