#!/usr/bin/env bash
# Build a Developer ID-signed, notarized Shotter DMG from a clean commit.
# Requires:
#   - Developer ID Application certificate in the login keychain
#   - notarytool keychain profile "shotter-notary"
#     (xcrun notarytool store-credentials shotter-notary --apple-id YOU --team-id NSD8UNQK9J)
#
# Notarization must return status Accepted. Anything else stops the script.
# If Apple is still processing when --wait gives up, the submission id and
# the staged file are left in dist/ so the same upload can be resumed.
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

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing to release: the working tree has uncommitted changes." >&2
  exit 1
fi

if [[ ! -d "$DIST" ]]; then
  mkdir -p "$DIST"
fi

notarize() {
  local artifact="$1"
  local label="$2"
  local output id status
  echo "Submitting ${label} for notarization..."
  output="$(xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" --wait)"
  printf '%s\n' "$output"
  id="$(printf '%s\n' "$output" | awk '/^  id: / { print $2; exit }')"
  status="$(printf '%s\n' "$output" | awk '/^  status: / { print $2; exit }')"
  if [[ -n "$id" ]]; then
    printf '%s\n' "$id" > "${artifact}.submission-id"
  fi
  if [[ "$status" != "Accepted" ]]; then
    echo "Notarization of ${label} is '${status:-unknown}', not Accepted." >&2
    if [[ -n "$id" ]]; then
      echo "Submission id ${id} is saved at ${artifact}.submission-id" >&2
      echo "Resume with: xcrun notarytool log ${id} --keychain-profile ${NOTARY_PROFILE}" >&2
    fi
    echo "Staged file kept at ${artifact}" >&2
    exit 1
  fi
}

echo "Building release from $(git rev-parse HEAD)"
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

rm -rf "$APP" "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
  ".build/arm64-apple-macosx/release/Shotter" \
  ".build/x86_64-apple-macosx/release/Shotter" \
  -output "$APP/Contents/MacOS/Shotter"
chmod +x "$APP/Contents/MacOS/Shotter"
cp "$PROJECT_DIR/scripts/Info.plist.template" "$APP/Contents/Info.plist"

# Sign the executable before the bundle. There are no nested frameworks.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/MacOS/Shotter"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# Apple notarizes the zip. Stapling happens on the local .app afterwards;
# the ticket is attached to the same signed bundle that goes into the DMG.
ditto -c -k --keepParent "$APP" "$ZIP"
notarize "$ZIP" "app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

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
notarize "$DMG" "DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type execute --verbose=4 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
hdiutil verify "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Ready: $DMG"
