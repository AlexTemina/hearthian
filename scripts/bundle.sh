#!/bin/bash
# Build Hearthian.app, install it in /Applications and (re)launch it.
# HEARTHIAN_APP_DIR overrides the install folder; HEARTHIAN_NO_LAUNCH=1 builds without launching.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="${HEARTHIAN_APP_DIR:-/Applications}/Hearthian.app"
[ "${HEARTHIAN_NO_LAUNCH:-}" = 1 ] || pkill -x Hearthian 2>/dev/null || true
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Hearthian "$app/Contents/MacOS/Hearthian"
if [ -f Resources/icon.png ]; then
  set=$(mktemp -d)/Hearthian.iconset
  mkdir -p "$set"
  for s in 16 32 128 256 512; do
    sips -z $s $s Resources/icon.png --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) Resources/icon.png --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$app/Contents/Resources/Hearthian.icns"
fi
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Hearthian</string>
  <key>CFBundleDisplayName</key><string>Hearthian</string>
  <key>CFBundleIdentifier</key><string>com.alextemina.hearthian</string>
  <key>CFBundleExecutable</key><string>Hearthian</string>
  <key>CFBundleIconFile</key><string>Hearthian</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST
# A stable identity keeps macOS permissions across rebuilds; ad-hoc resets them every build.
identity="${HEARTHIAN_SIGN_IDENTITY:-Hearthian Local Signing}"
if security find-identity -v -p codesigning | grep -q "\"$identity\""; then
  codesign --force --sign "$identity" "$app"
else
  echo "no '$identity' signing identity, signing ad-hoc (permissions reset on every build)" >&2
  codesign --force --sign - "$app"
fi
[ "${HEARTHIAN_NO_LAUNCH:-}" = 1 ] || open "$app"
echo "$app"
