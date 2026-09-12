#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
MODE="${1:-run}"
APP_BUNDLE="$PROJECT_ROOT/macos/build/ReleaseLocal/Ghostty.app"

case "$MODE" in
    run|--verify|--build-only) ;;
    *) echo "Usage: $0 [run|--verify|--build-only]" >&2; exit 2 ;;
esac

# Close only this source build. Ghostty asks before closing active sessions.
if [[ "$MODE" != --build-only && -d "$APP_BUNDLE" ]]; then
    osascript - "$APP_BUNDLE" <<'APPLESCRIPT'
on run argv
    set appPath to item 1 of argv
    if application appPath is running then tell application appPath to quit
end run
APPLESCRIPT
fi

zig build -Doptimize=ReleaseFast -Demit-macos-app=false -Dxcframework-target=native
macos/build.nu --configuration ReleaseLocal --native

if [[ "$MODE" != --build-only ]]; then
    open -n "$APP_BUNDLE"
    if [[ "$MODE" == --verify ]]; then
        sleep 2
        pgrep -f "$APP_BUNDLE/Contents/MacOS/ghostty" >/dev/null
    fi
fi
