#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"
mkdir -p "$ROOT/.build/verification" "$CLANG_MODULE_CACHE_PATH"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" -O \
    macOS/Sources/ViewerCore/DocumentLoader.swift macOS/Tests/CoreChecks.swift -o .build/core-checks
"$ROOT/.build/core-checks" | tee "$ROOT/.build/verification/core-report.json"
"$ROOT/Scripts/build-app.sh"
mkdir -p "$ROOT/.build/verification"
# Hide SwiftPM's build tree so resource fallback cannot mask a broken app bundle.
RESOURCE_BUILD="$ROOT/.build/macOS"
RESOURCE_HIDDEN="$ROOT/.build/macOS-resource-check-$$"
mv "$RESOURCE_BUILD" "$RESOURCE_HIDDEN"
trap 'mv "$RESOURCE_HIDDEN" "$RESOURCE_BUILD"' EXIT
"$ROOT/dist/엠디봄.app/Contents/MacOS/MarkdownViewer" --self-test "$ROOT/.build/verification/report.json"
