#!/bin/bash
# Bouwt "CSV Studio.app" in de map build/.  Vereist Xcode of de Command Line Tools (macOS 13+).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/CSV Studio.app"
BUILD_SYSTEM=(--build-system native)
swift build -c release "${BUILD_SYSTEM[@]}"
BIN="$(swift build -c release "${BUILD_SYSTEM[@]}" --show-bin-path)/CSVStudio"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CSVStudio"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Icoon (niet fataal als dit mislukt)
rm -rf build/icon.iconset
if swift tools/make_icon.swift build/icon.iconset 2>/dev/null && iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
  echo "Icoon gemaakt."
else
  echo "Icoon overgeslagen."
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Klaar: $APP"
open build
