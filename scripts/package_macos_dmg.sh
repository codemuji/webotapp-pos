#!/usr/bin/env bash
set -e

# ==============================================================================
# WebotApp Departmental POS — macOS DMG Packaging Script
# Run this script on macOS to build the Release App and generate an Apple DMG installer.
# ==============================================================================

echo "=== Building WebotApp Departmental POS for macOS ==="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$PROJECT_ROOT/apps/desktop"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="WebotApp Departmental POS"
APP_BUNDLE="$DESKTOP_DIR/build/macos/Build/Products/Release/$APP_NAME.app"
DMG_NAME="WebotApp-Departmental-POS-v1.0.0.dmg"
ZIP_NAME="WebotApp-Departmental-POS-macOS-v1.0.0.zip"

mkdir -p "$DIST_DIR"

cd "$DESKTOP_DIR"
echo "Fetching dependencies..."
flutter pub get

echo "Compiling macOS Release Binary..."
flutter build macos --release

if [ ! -d "$APP_BUNDLE" ]; then
  echo "Error: App bundle not found at: $APP_BUNDLE"
  exit 1
fi

echo "✓ Compiled app bundle successfully."

# 1. Package Portable Zip
echo "Creating portable zip archive: $DIST_DIR/$ZIP_NAME"
cd "$DESKTOP_DIR/build/macos/Build/Products/Release"
zip -r -y "$DIST_DIR/$ZIP_NAME" "$APP_NAME.app"

# 2. Build Drag-and-Drop DMG Installer
echo "Creating Apple Disk Image (DMG) installer: $DIST_DIR/$DMG_NAME"
DMG_STAGING="$PROJECT_ROOT/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$DIST_DIR/$DMG_NAME"

rm -rf "$DMG_STAGING"

echo "=== Build Complete! ==="
echo "DMG Installer: $DIST_DIR/$DMG_NAME"
echo "Portable Zip:  $DIST_DIR/$ZIP_NAME"

# 3. Optional: Upload to GitHub Release v1.0.0 if GitHub CLI is installed
if command -v gh &> /dev/null; then
  echo "GitHub CLI detected. Uploading DMG to GitHub Release v1.0.0..."
  gh release upload v1.0.0 "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$ZIP_NAME" --clobber || true
  echo "✓ Uploaded to GitHub Release v1.0.0"
fi

