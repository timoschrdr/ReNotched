#!/bin/bash
# Rebuilds Vendor/MediaRemoteAdapter.framework and mediaremote-adapter.pl from the pinned upstream commit,
# so you do not have to trust the binary in this repository:
#   ./Vendor/build-adapter.sh          then compare with `git diff --stat Vendor/` (or just keep the result)
set -euo pipefail
cd "$(dirname "$0")"

COMMIT=797729d9b16316dc313844476c153d7a107ca0df   # upstream v0.7.7 + 6 commits
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone --quiet https://github.com/ungive/mediaremote-adapter.git "$WORK/src"
git -C "$WORK/src" checkout --quiet "$COMMIT"
cd "$WORK/src"

# Same source list as upstream's CMakeLists.txt
SOURCES=$(sed -n '/set(ADAPTER_SOURCES/,/)/p' CMakeLists.txt | grep -o 'src/[A-Za-z_/]*\.m')
mkdir -p "$OLDPWD/MediaRemoteAdapter.framework"
clang -dynamiclib -arch arm64 -O2 -fobjc-arc -fvisibility=default -mmacosx-version-min=14.0 \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -Iinclude -Isrc $SOURCES \
  -install_name @rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter \
  -o "$OLDPWD/MediaRemoteAdapter.framework/MediaRemoteAdapter"
cp bin/mediaremote-adapter.pl "$OLDPWD/mediaremote-adapter.pl"
codesign --force --deep --sign - "$OLDPWD/MediaRemoteAdapter.framework"
echo "Built from upstream $COMMIT"
