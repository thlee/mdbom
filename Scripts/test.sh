#!/bin/bash
# Compatibility entry point; macOS implementation lives with the Mac project.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/macOS/Scripts/test.sh" "$@"
