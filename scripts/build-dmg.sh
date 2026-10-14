#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

APP_NAME="GlmUsageBar"
DIST="dist"
DMG="$DIST/$APP_NAME.dmg"
VOLNAME="GLM Usage"
STAGING=$(mktemp -d)

trap 'rm -rf "$STAGING"' EXIT

cp -R "$DIST/$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG"

echo "Built $DMG"
ls -lh "$DMG"
