#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DESTINATION="${1:-$ROOT/dist}"
mkdir -p "$DESTINATION"
DESTINATION="$(cd "$DESTINATION" && pwd)"
APP="$DESTINATION/엠디봄.app"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$ROOT/.build/cache" "$ROOT/.build/config" "$ROOT/.build/security"
BUILD_OPTIONS=( -c release --arch arm64 --disable-sandbox --package-path "$ROOT/macOS" --scratch-path "$ROOT/.build/macOS"
    --cache-path "$ROOT/.build/cache" --config-path "$ROOT/.build/config" --security-path "$ROOT/.build/security" )

# No package resolution or network access is needed; web dependencies are committed assets.
swift build "${BUILD_OPTIONS[@]}"
BIN_DIR="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Remove the obsolete resource bundle from builds made before the package split.
rm -rf "$APP/Contents/Resources/MarkdownViewer_RendererAssets.bundle"
cp "$BIN_DIR/MarkdownViewer" "$APP/Contents/MacOS/MarkdownViewer"
cp "$ROOT/macOS/Packaging/Info.plist" "$APP/Contents/Info.plist"
for RESOURCE in "$BIN_DIR"/*.bundle; do
    if [ -d "$RESOURCE" ]; then
        NAME="$(basename "$RESOURCE")"
        # SwiftPM searches for this resource bundle at the top level of the app's resource directory.
        ditto "$RESOURCE" "$APP/Contents/Resources/$NAME"
    fi
done
cp "$ROOT/HELP.md" "$APP/Contents/Resources/HELP.md"
ditto "$ROOT/ThirdPartyLicenses" "$APP/Contents/Resources/ThirdPartyLicenses"
if [ -f "$ROOT/macOS/Packaging/AppIcon.icns" ]; then
    cp "$ROOT/macOS/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
