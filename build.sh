#!/bin/bash
# Builds ReNotched.app into ./build
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/ReNotched.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ReNotched "$APP/Contents/MacOS/ReNotched"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/de.lproj "$APP/Contents/Resources/"
cp Vendor/mediaremote-adapter.pl "$APP/Contents/Resources/"
cp -R Vendor/MediaRemoteAdapter.framework "$APP/Contents/Resources/"
cp Vendor/MediaRemoteAdapter.LICENSE "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "Done: $APP"
