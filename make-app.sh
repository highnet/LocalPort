#!/bin/bash
# Builds LocalPort.app from the SwiftPM release binary and installs it.
#   ./make-app.sh            -> builds ./LocalPort.app
#   ./make-app.sh --install  -> also copies it into /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="LocalPort.app"
BIN_NAME="LocalPorts"   # SwiftPM product name

echo "==> Generating app icon"
swift make-icon.swift
iconutil -c icns LocalPort.iconset -o AppIcon.icns
rm -rf LocalPort.iconset

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN_NAME" "$APP/Contents/MacOS/LocalPort"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>LocalPort</string>
    <key>CFBundleDisplayName</key>        <string>LocalPort</string>
    <key>CFBundleIdentifier</key>         <string>com.highnet.localport</string>
    <key>CFBundleVersion</key>            <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleExecutable</key>         <string>LocalPort</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Ad-hoc codesign so macOS runs it without Gatekeeper prompts.
codesign --force --deep --sign - "$APP" 2>/dev/null || true

if [[ "${1:-}" == "--install" ]]; then
    echo "==> Installing to /Applications"
    rm -rf "/Applications/$APP"
    cp -R "$APP" "/Applications/$APP"
    echo "Installed /Applications/$APP"
else
    echo "Built $APP. Install with: ./make-app.sh --install"
fi
