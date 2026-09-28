#!/usr/bin/env bash
set -euo pipefail

swift build -c release

CODESIGN_IDENTITY="${ONESHOT_CODESIGN_IDENTITY:-One Shot Local Development}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/create-dev-certificate.sh"

APP_DIR=".build/One Shot.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/OneShot" "$MACOS/OneShot"

cp "$SCRIPT_DIR/Info.plist.template" "$CONTENTS/Info.plist"

chmod +x "$MACOS/OneShot"

codesign \
    --force \
    --deep \
    --options runtime \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_DIR"

echo "Built and signed $APP_DIR with identity '$CODESIGN_IDENTITY'"
