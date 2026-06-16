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

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Shotter</string>
    <key>CFBundleIdentifier</key>
    <string>local.shotter.app</string>
    <key>CFBundleName</key>
    <string>Shotter</string>
    <key>CFBundleDisplayName</key>
    <string>Shotter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS/Shotter"

codesign \
    --force \
    --deep \
    --options runtime \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_DIR"

echo "Built and signed $APP_DIR with identity '$CODESIGN_IDENTITY'"
