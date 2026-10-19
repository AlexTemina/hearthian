#!/bin/bash
# Build a drag-to-install disk image: dist/Hearthian-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."
stage=$(mktemp -d)
HEARTHIAN_APP_DIR="$stage" HEARTHIAN_NO_LAUNCH=1 ./scripts/bundle.sh >/dev/null
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$stage/Hearthian.app/Contents/Info.plist")
ln -s /Applications "$stage/Applications"
mkdir -p dist
rm -f "dist/Hearthian-$version.dmg"
hdiutil create -volname Hearthian -srcfolder "$stage" -ov -format UDZO "dist/Hearthian-$version.dmg" >/dev/null
echo "dist/Hearthian-$version.dmg"
