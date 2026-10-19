#!/bin/bash
# Build Parte.app into ~/Applications and (re)launch it.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="$HOME/Applications/Parte.app"
pkill -x Parte 2>/dev/null || true
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Parte "$app/Contents/MacOS/Parte"
if [ -f Resources/icon.png ]; then
  set=$(mktemp -d)/Parte.iconset
  mkdir -p "$set"
  for s in 16 32 128 256 512; do
    sips -z $s $s Resources/icon.png --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) Resources/icon.png --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$app/Contents/Resources/Parte.icns"
fi
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Parte</string>
  <key>CFBundleDisplayName</key><string>Parte</string>
  <key>CFBundleIdentifier</key><string>com.alextemina.parte</string>
  <key>CFBundleExecutable</key><string>Parte</string>
  <key>CFBundleIconFile</key><string>Parte</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app" >/dev/null 2>&1 || true
open "$app"
echo "$app"
