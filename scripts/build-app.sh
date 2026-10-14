#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP_NAME="GlmUsageBar"
DIST="dist"
APP="$DIST/$APP_NAME.app"

if [ ! -d "$DIST/$APP_NAME.iconset" ]; then
    swift scripts/make-icon.swift "$DIST/$APP_NAME.iconset"
fi
iconutil -c icns "$DIST/$APP_NAME.iconset" -o "$DIST/$APP_NAME.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/$APP_NAME "$APP/Contents/MacOS/$APP_NAME"
cp "$DIST/$APP_NAME.icns" "$APP/Contents/Resources/$APP_NAME.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GlmUsageBar</string>
    <key>CFBundleIdentifier</key>
    <string>local.glm.usage-bar</string>
    <key>CFBundleName</key>
    <string>GLM Usage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>GlmUsageBar</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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

codesign --force --deep -s - "$APP" 2>/dev/null || true
echo "Built $APP"
