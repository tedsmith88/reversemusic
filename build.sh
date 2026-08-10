#!/bin/bash
set -e

echo "Building Reverse Music..."
swift build -c release

APP_NAME="ReverseMusic"
APP_DIR="build/$APP_NAME.app"
BINARY=".build/release/$APP_NAME"

echo "Creating app bundle..."
rm -rf build
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ReverseMusic</string>
    <key>CFBundleIdentifier</key><string>com.reversemusic.app</string>
    <key>CFBundleName</key><string>Reverse Music</string>
    <key>CFBundleDisplayName</key><string>Reverse Music</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Reverse Music needs your microphone to record singing.</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
</dict>
</plist>
PLIST

cat > /tmp/rm_entitlements.plist << 'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key><true/>
    <key>com.apple.security.app-sandbox</key><false/>
</dict>
</plist>
ENT

echo "Signing..."
codesign --force --sign - --entitlements /tmp/rm_entitlements.plist "$APP_DIR"

echo ""
echo "Done! App is at: $APP_DIR"
echo "   Run with: open $APP_DIR"
