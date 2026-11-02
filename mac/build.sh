#!/bin/bash
# Builds "밧줄 태우지 마라.app" next to this script. Run from Terminal so the signature gets Apple's timestamp.
set -euo pipefail
cd "$(dirname "$0")"
APP="밧줄 태우지 마라.app"
rm -rf "$APP" build
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources/assets"
swiftc -O -swift-version 5 -target arm64-apple-macos13 -o build/RopeIdle src/main.swift -framework Cocoa -framework WebKit
cp build/RopeIdle "$APP/Contents/MacOS/RopeIdle"
cp src/rope.html "$APP/Contents/Resources/"
cp src/assets/textures.js "$APP/Contents/Resources/assets/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>밧줄 태우지 마라</string>
  <key>CFBundleDisplayName</key><string>밧줄 태우지 마라</string>
  <key>CFBundleIdentifier</key><string>ai.multi-turn.dont-burn-the-rope</string>
  <key>CFBundleExecutable</key><string>RopeIdle</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
rm -rf build
xattr -cr "$APP" 2>/dev/null || true
ID="Developer ID Application: Multi-turn Inc. (8V3Z27Z6RY)"
if security find-identity -v -p codesigning | grep -q "$ID"; then
  codesign --force --options runtime --timestamp -s "$ID" "$APP" 2>/dev/null \
    || { echo "WARNING: no Apple timestamp; signed without it. Run ./build.sh from Terminal."; codesign --force --options runtime --timestamp=none -s "$ID" "$APP"; }
else
  codesign --force -s - "$APP"
fi
echo "built $(pwd)/$APP"
