#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MP4缩略图修复器"
APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/$APP_NAME.dmg"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$ROOT/build" "$ROOT/dist"
mkdir -p "$ROOT/build" "$APP/Contents/MacOS" "$APP/Contents/Resources"

rsvg-convert -w 1024 -h 1024 "$ROOT/Assets/AppIcon.svg" \
  -o "$ROOT/build/AppIcon-1024.png"
ICONSET="$ROOT/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT/build/AppIcon-1024.png" \
    --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$ROOT/build/AppIcon-1024.png" \
    --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc "$ROOT/Sources/main.swift" \
  -sdk "$SDK" \
  -target "$(uname -m)-apple-macos13.0" \
  -framework AppKit \
  -o "$APP/Contents/MacOS/MP4ThumbnailFixer"

cp /opt/homebrew/bin/ffmpeg "$APP/Contents/Resources/ffmpeg"
chmod +x "$APP/Contents/Resources/ffmpeg"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MP4ThumbnailFixer</string>
  <key>CFBundleIdentifier</key>
  <string>com.rfbz.mp4-thumbnail-fixer</string>
  <key>CFBundleName</key>
  <string>MP4缩略图修复器</string>
  <key>CFBundleDisplayName</key>
  <string>MP4缩略图修复器</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

# 本地可直接运行；未加入 Apple Developer 签名。
codesign --force --deep --sign - "$APP" >/dev/null

mkdir -p "$ROOT/build/dmg"
cp -R "$APP" "$ROOT/build/dmg/"
ln -s /Applications "$ROOT/build/dmg/Applications"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$ROOT/build/dmg" \
  -ov -format UDZO "$DMG" >/dev/null

echo "已生成：$DMG"
