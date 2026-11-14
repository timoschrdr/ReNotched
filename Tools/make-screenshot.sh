#!/bin/bash
# Renders docs/screenshot.png from the app's real views (Tools/Screenshot/main.swift) and captures it.
# Needs Screen Recording permission for the terminal. Usage: ./Tools/make-screenshot.sh
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
swiftc -O -target arm64-apple-macosx26.0 $(find Sources/ReNotched -name '*.swift' ! -name main.swift) \
  Tools/Screenshot/main.swift -o "$WORK/screenshot"
"$WORK/screenshot" > "$WORK/window" &
while [ ! -s "$WORK/window" ]; do sleep 0.2; done
screencapture -x -o -l"$(cat "$WORK/window")" docs/screenshot.png
wait
echo "Done: docs/screenshot.png"
