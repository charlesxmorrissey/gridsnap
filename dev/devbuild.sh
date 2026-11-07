#!/bin/sh -e
# Build the fork and relabel the output as the dev bundle so it keeps its own Accessibility grant and settings.
cd "$(dirname "$0")/.." && ./build.sh >/dev/null
plutil -replace CFBundleIdentifier -string com.zerodivisionerror.gridsnap.dev build/GridSnap.app/Contents/Info.plist
plutil -replace CFBundleName -string "GridSnap Dev" build/GridSnap.app/Contents/Info.plist
codesign --force --sign "GridSnap Dev" build/GridSnap.app 2>&1 | tail -1
# install as the daily copy: quit the running one, copy over, relaunch
pkill -x GridSnap || true; sleep 1
rm -rf "/Applications/GridSnap Dev.app" && ditto build/GridSnap.app "/Applications/GridSnap Dev.app"
open "/Applications/GridSnap Dev.app"
echo "dev build installed and running from /Applications/GridSnap Dev.app"
