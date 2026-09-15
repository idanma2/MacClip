#!/bin/bash
# Builds MacClip in release configuration, hand-assembles the .app bundle,
# ad-hoc code-signs it, and packages a DMG with a custom icon (both on the
# mounted volume and the .dmg file itself). Same approach as MacSecureSSH's
# Scripts/build-dmg.sh — Command Line Tools only, no Xcode.app/xcodebuild
# available in this environment. Ad-hoc signed only, no Developer ID cert;
# fine for running locally, Gatekeeper will block it elsewhere until it's
# properly signed + notarized.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/App"
DIST="$ROOT/dist"
RESOURCES="$ROOT/Resources"
ICON="$RESOURCES/AppIcon.icns"

echo "== Building release =="
cd "$APP_DIR"
swift build -c release
BINPATH="$APP_DIR/.build/arm64-apple-macosx/release"

echo "== Assembling .app bundle =="
STAGE="$DIST/MacClip.app"
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$BINPATH/MacClip" "$STAGE/Contents/MacOS/MacClip"
cp "$RESOURCES/Info.plist" "$STAGE/Contents/Info.plist"
cp "$ICON" "$STAGE/Contents/Resources/AppIcon.icns"

echo "== Code signing (ad-hoc) =="
codesign --force --deep --sign - "$STAGE"
codesign --verify --verbose "$STAGE"

echo "== Verifying it actually launches (not just that it built) =="
pkill -f "MacClip.app/Contents/MacOS/MacClip" 2>/dev/null || true
sleep 1
open "$STAGE"
sleep 2
if ! pgrep -f "MacClip.app/Contents/MacOS/MacClip" > /dev/null; then
  echo "!! App did not stay running after launch — check ~/Library/Logs/DiagnosticReports for a crash report before packaging."
  exit 1
fi
osascript -e 'tell application "MacClip" to quit' 2>/dev/null || pkill -f "MacClip.app/Contents/MacOS/MacClip" 2>/dev/null || true

echo "== Packaging DMG =="
STAGE_DIR="$DIST/dmg-staging"
RW_DMG="$DIST/MacClip-rw.dmg"
FINAL_DMG="$DIST/MacClip.dmg"
rm -rf "$STAGE_DIR" "$RW_DMG" "$FINAL_DMG"
mkdir -p "$STAGE_DIR"
cp -R "$STAGE" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$ICON" "$STAGE_DIR/.VolumeIcon.icns"

hdiutil create -volname "MacClip" -srcfolder "$STAGE_DIR" -fs HFS+ -format UDRW -ov "$RW_DMG"
MOUNT_OUT=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)
MOUNT_POINT=$(echo "$MOUNT_OUT" | grep -o "/Volumes/MacClip.*")
SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -a C "$MOUNT_POINT"
hdiutil detach "$MOUNT_POINT"
hdiutil convert "$RW_DMG" -format UDZO -o "$FINAL_DMG"
rm -f "$RW_DMG"
rm -rf "$STAGE_DIR"

# Custom icon on the .dmg file itself (not just the mounted volume) — the
# classic resource-fork trick: give the icns file a self-referential icon
# resource, extract it, append it to the target file's own resource fork.
cp "$ICON" "$DIST/icon_for_dmg.icns"
sips -i "$DIST/icon_for_dmg.icns" > /dev/null
DeRez -only icns "$DIST/icon_for_dmg.icns" > "$DIST/icon.rsrc"
Rez -append "$DIST/icon.rsrc" -o "$FINAL_DMG"
SetFile -a C "$FINAL_DMG"
rm -f "$DIST/icon_for_dmg.icns" "$DIST/icon.rsrc"

echo "== Done =="
ls -la "$FINAL_DMG"
