#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release-package"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="口袋密码"
EXECUTABLE_NAME="PocketPass"
APP_VERSION="1.2"
BUILD_NUMBER="3"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="PocketPass-2026082201.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="口袋密码 V1.2"

if [[ "$BUILD_DIR" != "$PROJECT_DIR/.build/release-package" || "$DIST_DIR" != "$PROJECT_DIR/dist" ]]; then
  echo "发布目录校验失败" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$DIST_DIR"

ARM64_SCRATCH="$PROJECT_DIR/.build/release-arm64"
X86_64_SCRATCH="$PROJECT_DIR/.build/release-x86_64"

swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$ARM64_SCRATCH" \
  --configuration release \
  --product "$EXECUTABLE_NAME" \
  --triple arm64-apple-macosx26.0

swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$X86_64_SCRATCH" \
  --configuration release \
  --product "$EXECUTABLE_NAME" \
  --triple x86_64-apple-macosx26.0

ARM64_BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --scratch-path "$ARM64_SCRATCH" --configuration release --triple arm64-apple-macosx26.0 --show-bin-path)"
X86_64_BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --scratch-path "$X86_64_SCRATCH" --configuration release --triple x86_64-apple-macosx26.0 --show-bin-path)"

lipo -create \
  "$ARM64_BIN_DIR/$EXECUTABLE_NAME" \
  "$X86_64_BIN_DIR/$EXECUTABLE_NAME" \
  -output "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$ARM64_BIN_DIR/${EXECUTABLE_NAME}_${EXECUTABLE_NAME}.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
plutil -create xml1 "$INFO_PLIST"
plutil -insert CFBundleDisplayName -string "$APP_NAME" "$INFO_PLIST"
plutil -insert CFBundleDevelopmentRegion -string zh-Hans "$INFO_PLIST"
plutil -insert CFBundleExecutable -string "$EXECUTABLE_NAME" "$INFO_PLIST"
plutil -insert CFBundleIconFile -string PocketLogo.icns "$INFO_PLIST"
plutil -insert CFBundleIdentifier -string com.loongyu.pocketpass "$INFO_PLIST"
plutil -insert CFBundleName -string "$EXECUTABLE_NAME" "$INFO_PLIST"
plutil -insert CFBundlePackageType -string APPL "$INFO_PLIST"
plutil -insert CFBundleShortVersionString -string "$APP_VERSION" "$INFO_PLIST"
plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$INFO_PLIST"
plutil -insert LSMinimumSystemVersion -string 26.0 "$INFO_PLIST"
plutil -insert NSHighResolutionCapable -bool true "$INFO_PLIST"

ICON_SOURCE="$PROJECT_DIR/Sources/PocketPass/Resources/PocketLogo.png"
ICONSET="$BUILD_DIR/PocketLogo.iconset"
mkdir -p "$ICONSET"
for spec in \
  "16 icon_16x16.png" "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  pixels="${spec%% *}"
  filename="${spec#* }"
  sips -z "$pixels" "$pixels" "$ICON_SOURCE" --out "$ICONSET/$filename" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/PocketLogo.icns"
cp "$ICON_SOURCE" "$APP_PATH/Contents/Resources/PocketLogo.png"
cp "$PROJECT_DIR/Sources/PocketPass/Resources/PocketLogoMark.png" \
  "$APP_PATH/Contents/Resources/PocketLogoMark.png"
mkdir -p "$APP_PATH/Contents/Resources/en.lproj"
cp "$PROJECT_DIR/Sources/PocketPass/Resources/en.lproj/Localizable.strings" \
  "$APP_PATH/Contents/Resources/en.lproj/Localizable.strings"
cp "$PROJECT_DIR/Sources/PocketPass/Resources/en.lproj/InfoPlist.strings" \
  "$APP_PATH/Contents/Resources/en.lproj/InfoPlist.strings"
mkdir -p "$APP_PATH/Contents/Resources/zh-Hans.lproj"
cp "$PROJECT_DIR/Sources/PocketPass/Resources/zh-Hans.lproj/InfoPlist.strings" \
  "$APP_PATH/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"

xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

BACKGROUND_PATH="$BUILD_DIR/dmg-background.png"
xcrun swift "$PROJECT_DIR/Tools/GenerateDMGBackground.swift" "$BACKGROUND_PATH"

DMG_TOOLS_DIR="$PROJECT_DIR/.build/release-tools"
if ! PYTHONPATH="$DMG_TOOLS_DIR" python3 -c 'import dmgbuild' >/dev/null 2>&1; then
  python3 -m pip install --disable-pip-version-check --target "$DMG_TOOLS_DIR" "dmgbuild==1.6.5"
fi

rm -f "$DMG_PATH"
PYTHONPATH="$DMG_TOOLS_DIR" python3 -m dmgbuild \
  -s "$PROJECT_DIR/Scripts/dmg-settings.py" \
  -Dapp="$APP_PATH" \
  -Dbackground="$BACKGROUND_PATH" \
  "$VOLUME_NAME" "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null

echo "已生成：$DMG_PATH"
echo "架构：$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME")"
shasum -a 256 "$DMG_PATH"
