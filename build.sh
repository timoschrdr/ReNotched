#!/bin/bash
# Builds ReNotched..app (shown as "ReNotched.") into ./build
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
# The file name ends in a dot so Finder and the Dock show "ReNotched."
APP="build/ReNotched..app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ReNotched "$APP/Contents/MacOS/ReNotched"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
# ICON=island ./build.sh builds with the alternative island icon (the default is the penguin)
ICON_DIR=$(mktemp -d)
cp -R "Resources/$([ "${ICON:-}" = "island" ] && echo AppIconIsland || echo AppIcon).icon" "$ICON_DIR/AppIcon.icon"
xcrun actool "$ICON_DIR/AppIcon.icon" --compile "$APP/Contents/Resources" --platform macosx \
  --minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist /dev/null > /dev/null
rm -rf "$ICON_DIR"
cp -R Resources/de.lproj "$APP/Contents/Resources/"
cp Resources/IslandIcon-light.png Resources/IslandIcon-dark.png "$APP/Contents/Resources/"
cp Vendor/mediaremote-adapter.pl "$APP/Contents/Resources/"
cp -R Vendor/MediaRemoteAdapter.framework "$APP/Contents/Resources/"
cp Vendor/MediaRemoteAdapter.LICENSE "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "Done: $APP"
