#!/usr/bin/env bash
set -euo pipefail

# Builds a drag-to-Applications DMG for Clove.
#
#   ./tools/MakeDMG.sh
#
# Optional env:
#   CONFIG=Release          build configuration (default Release)
#   SIGN_ID="Developer ID Application: …"   ad-hoc if unset on Release
#
# For store distribution you also need notarization (see bottom of script output).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="Clove"
APP_NAME="Clove"
CONFIG="${CONFIG:-Release}"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
DIST="$ROOT/dist"
STAGE="$ROOT/build/dmg-stage"

echo "→ Building $SCHEME ($CONFIG)…"
xcodebuild \
  -project "$ROOT/Clove.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  build

if [[ ! -d "$APP" ]]; then
  echo "Build failed: $APP not found" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"

mkdir -p "$DIST"
rm -rf "$STAGE"
mkdir -p "$STAGE"

if command -v create-dmg >/dev/null 2>&1; then
  echo "→ Creating styled DMG with create-dmg…"
  rm -f "$DMG_PATH" "${DMG_PATH%.dmg}-temp.dmg"
  VOLICON="$APP/Contents/Resources/AppIcon.icns"
  if [[ -f "$VOLICON" ]]; then
    create-dmg \
      --volname "$APP_NAME" \
      --volicon "$VOLICON" \
      --window-pos 200 120 \
      --window-size 660 400 \
      --icon-size 128 \
      --icon "$APP_NAME.app" 180 185 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 480 185 \
      --no-internet-enable \
      "$DMG_PATH" \
      "$APP"
  else
    create-dmg \
      --volname "$APP_NAME" \
      --window-pos 200 120 \
      --window-size 660 400 \
      --icon-size 128 \
      --icon "$APP_NAME.app" 180 185 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 480 185 \
      --no-internet-enable \
      "$DMG_PATH" \
      "$APP"
  fi
else
  echo "→ create-dmg not found; using basic hdiutil layout"
  echo "  (Install for the polished window: brew install create-dmg)"
  cp -R "$APP" "$STAGE/"
  ln -sf /Applications "$STAGE/Applications"
  RMG="$DIST/.temp-$APP_NAME.rw.dmg"
  rm -f "$RMG" "$DMG_PATH"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RMG"
  MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RMG" | awk '/\/Volumes\// {print $3; exit}')"
  echo "→ Mounted at $MOUNT"
  sleep 1
  osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "$APP_NAME.app" of container window to {180, 185}
    set position of item "Applications" of container window to {480, 185}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF
  chmod -Rf go-w "$MOUNT" || true
  hdiutil detach "$MOUNT"
  hdiutil convert "$RMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
  rm -f "$RMG"
fi

rm -rf "$STAGE"

echo ""
echo "✓ $DMG_PATH"
echo "  version $VERSION ($BUILD)"
echo ""
echo "Ship checklist:"
echo "  1. Sign with Developer ID Application (Xcode → Release → Signing)"
echo "  2. Notarize: xcrun notarytool submit \"$DMG_PATH\" --keychain-profile AC_PASSWORD --wait"
echo "  3. Staple:   xcrun stapler staple \"$DMG_PATH\""
echo "  4. Upload to Lemon Squeezy as the product file"
