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
# Signed with the self-signed certificate from Tools/make-signing-identity.sh if it exists, so the app keeps one
# identity and its permissions (Bluetooth, Full Disk Access) across updates; otherwise ad hoc.
IDENTITY="ReNotched Self-Signed"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  SIGN="$IDENTITY"
else
  SIGN="-"
  echo "Note: signing ad hoc. Run ./Tools/make-signing-identity.sh once so updates keep their permissions."
fi
# Hardened runtime: other processes cannot inject code into the app to borrow its permissions (Full Disk Access)
codesign --force --deep --options runtime --sign "$SIGN" "$APP"
echo "Done: $APP (signed with ${SIGN/-/ad hoc signature})"
