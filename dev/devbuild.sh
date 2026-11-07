#!/bin/sh -e
# Build the fork and relabel the output as the dev bundle so it keeps its own Accessibility grant and settings.
cd "$(dirname "$0")/.." && ./build.sh >/dev/null
plutil -replace CFBundleIdentifier -string com.zerodivisionerror.gridsnap.dev build/GridSnap.app/Contents/Info.plist
plutil -replace CFBundleName -string "GridSnap Dev" build/GridSnap.app/Contents/Info.plist
codesign --force --sign "GridSnap Dev" build/GridSnap.app 2>&1 | tail -1
echo "dev build ready"
