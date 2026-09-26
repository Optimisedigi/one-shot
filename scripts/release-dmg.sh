#!/usr/bin/env bash
# Build a Developer ID-signed, notarized Shotter DMG from the current commit.
# Requires:
#   - Developer ID Application certificate in the login keychain
#   - notarytool keychain profile "shotter-notary"
#     (xcrun notarytool store-credentials shotter-notary --apple-id YOU --team-id NSD8UNQK9J)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

IDENTITY="${SHOTTER_CODESIGN_IDENTITY:-Developer ID Application: Peter Tu (NSD8UNQK9J)}"
NOTARY_PROFILE="${SHOTTER_NOTARY_PROFILE:-shotter-notary}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/scripts/Info.plist.template")"

DIST="$PROJECT_DIR/dist"
APP="$DIST/Shotter.app"
DMG="$DIST/Shotter-${VERSION}-macOS.dmg"
STAGE="$DIST/dmg-stage"
ZIP="$DIST/Shotter-${VERSION}-macOS.zip"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "Building release from $(git rev-parse --short HEAD)"
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

CONTENTS="$APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
lipo -create \
  ".build/arm64-apple-macosx/release/Shotter" \
  ".build/x86_64-apple-macosx/release/Shotter" \
  -output "$CONTENTS/MacOS/Shotter"
chmod +x "$CONTENTS/MacOS/Shotter"
cp "$PROJECT_DIR/scripts/Info.plist.template" "$CONTENTS/Info.plist"

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
echo "Submitting app for notarization..."
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Shotter.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Shotter" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"
echo "Submitting DMG for notarization..."
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type execute --verbose=4 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" || true
hdiutil verify "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Ready: $DMG"
