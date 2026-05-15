#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/FocusFlow"
BUILD_DIR="$PACKAGE_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/FocusFlow.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST_SRC="$PACKAGE_DIR/Sources/FocusFlow/Resources/Info.plist"
INFO_PLIST_DST="$CONTENTS_DIR/Info.plist"
RESOURCE_SRC_DIR="$PACKAGE_DIR/Sources/FocusFlow/Resources"

swift build -c release --package-path "$PACKAGE_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/FocusFlow" "$MACOS_DIR/FocusFlow"
chmod +x "$MACOS_DIR/FocusFlow"

cp "$INFO_PLIST_SRC" "$INFO_PLIST_DST"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable FocusFlow" "$INFO_PLIST_DST"

if [ -d "$RESOURCE_SRC_DIR" ]; then
  while IFS= read -r -d '' resource; do
    cp -R "$resource" "$RESOURCES_DIR/"
  done < <(find "$RESOURCE_SRC_DIR" -mindepth 1 -maxdepth 1 ! -name "Info.plist" -print0)
fi

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

# Ad-hoc signing is enough for CI artifacts and local smoke testing.
# Release distribution still needs Developer ID signing and notarization.
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

(
  cd "$DIST_DIR"
  ditto -c -k --keepParent "FocusFlow.app" "FocusFlow.app.zip"
)

echo "Packaged $APP_DIR"
echo "Created $DIST_DIR/FocusFlow.app.zip"
