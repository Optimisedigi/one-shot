#!/usr/bin/env bash
set -euo pipefail

swift build -c release

CODESIGN_IDENTITY="${SHOTTER_CODESIGN_IDENTITY:-Shotter Local Development}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/create-dev-certificate.sh"

APP_DIR=".build/Shotter.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/Shotter" "$MACOS/Shotter"

cp "$SCRIPT_DIR/Info.plist.template" "$CONTENTS/Info.plist"

chmod +x "$MACOS/Shotter"

codesign \
    --force \
    --deep \
    --options runtime \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_DIR"

echo "Built and signed $APP_DIR with identity '$CODESIGN_IDENTITY'"
