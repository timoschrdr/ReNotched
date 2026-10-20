#!/bin/bash
# Exports the Liquid Glass renditions of both icons with Icon Composer's command-line tool and writes the
# README images: docs/icon-light.png, docs/icon-dark.png (penguin), docs/icon-island-light.png, docs/icon-island-dark.png.
# Needs Xcode 26 or later. Usage: ./Tools/make-icon-previews.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export_icon() {   # <icon dir> <rendition> <output>
  "$ICTOOL" "$1" --export-image --output-file "$WORK/full.png" --platform macOS --rendition "$2" --width 1024 --height 1024 --scale 1 > /dev/null
  sips -Z 512 "$WORK/full.png" --out "$3" > /dev/null
}
export_icon Resources/AppIcon.icon Default docs/icon-light.png
export_icon Resources/AppIcon.icon Dark docs/icon-dark.png
export_icon Resources/AppIconIsland.icon Default docs/icon-island-light.png
export_icon Resources/AppIconIsland.icon Dark docs/icon-island-dark.png
echo "Done: docs/icon-*.png"
