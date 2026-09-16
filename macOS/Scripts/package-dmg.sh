#!/bin/bash
# Package an already-built, verified app. Build/test it first with Scripts/test.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DESTINATION="${1:-$ROOT/dist}"
APP="${2:-$ROOT/dist/엠디봄.app}"
if [ ! -d "$APP" ]; then
    echo 'Build the app first: ./Scripts/build-app.sh' >&2
    exit 1
fi
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
codesign --verify --deep --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print MDBomDisplayVersion' "$APP/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*(-beta\.[0-9]+)?$ ]]; then
    echo "Unexpected app version: $VERSION" >&2
    exit 1
fi
lipo "$APP/Contents/MacOS/MarkdownViewer" -verify_arch arm64
mkdir -p "$DESTINATION"
DESTINATION="$(cd "$DESTINATION" && pwd)"
NAME="MDBom-$VERSION-macOS-arm64.dmg"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mdbom-dmg.XXXXXX")"
MOUNT="$WORK/mounted"
MOUNTED=0
cleanup() {
    if [ "$MOUNTED" = 1 ]; then
        if ! hdiutil detach "$MOUNT" -quiet; then
            echo "Could not detach $MOUNT; temporary files retained." >&2
            return
        fi
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$WORK/staging" "$MOUNT"
ditto "$APP" "$WORK/staging/엠디봄.app"
ln -s /Applications "$WORK/staging/Applications"
cp "$ROOT/HELP.md" "$WORK/staging/HELP.md"
cp "$ROOT/macOS/Packaging/DMG-설치안내.txt" "$WORK/staging/설치안내.txt"
hdiutil create -quiet -volname "MDBom $VERSION" -srcfolder "$WORK/staging" \
    -format UDZO -imagekey zlib-level=9 -fs HFS+ "$WORK/package.dmg"
hdiutil verify "$WORK/package.dmg"
hdiutil attach "$WORK/package.dmg" -readonly -nobrowse -mountpoint "$MOUNT" -quiet
MOUNTED=1
# Inspect the packaged copy, not just the source directory.
test "$(readlink "$MOUNT/Applications")" = /Applications
test -s "$MOUNT/설치안내.txt"
cmp "$ROOT/HELP.md" "$MOUNT/HELP.md"
cmp "$ROOT/HELP.md" "$MOUNT/엠디봄.app/Contents/Resources/HELP.md"
codesign --verify --deep --strict "$MOUNT/엠디봄.app"
cmp "$APP/Contents/MacOS/MarkdownViewer" "$MOUNT/엠디봄.app/Contents/MacOS/MarkdownViewer"
cmp "$APP/Contents/Info.plist" "$MOUNT/엠디봄.app/Contents/Info.plist"
hdiutil detach "$MOUNT" -quiet
MOUNTED=0
mv "$WORK/package.dmg" "$DESTINATION/$NAME"
(cd "$DESTINATION" && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "Verified installer: $DESTINATION/$NAME"
