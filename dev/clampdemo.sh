#!/bin/sh
# Records the clamp before/after clips to /tmp/clamp-before.mov and /tmp/clamp-after.mov (display 1, 32 seconds each).
# Log: /tmp/gs-clampdemo.log, ends with "finished". Both takes run upstream's own source, so the panels look the same
# and only the drag differs: "before" is upstream/master as it is, "after" is upstream/master with GridView.track
# changed to keep the edge cell outside the panel. The builds happen in a scratch worktree (/tmp/gs-up) before the
# Start dialog. If track() changed upstream, the patch stops with an assertion and nothing is recorded.
# At the end the fork's own dev build goes back in. Needs Accessibility and Screen Recording:
#   open -na Ghostty --args -e "$PWD/dev/clampdemo.sh"
cd "$(dirname "$0")/.." || exit 1
D=com.zerodivisionerror.gridsnap.dev; L=/tmp/gs-clampdemo.log; : > $L; R=$PWD; W=/tmp/gs-up
mkdir -p build
swiftc -O dev/clampdemo.swift -o build/clampdemo >> $L 2>&1 && swiftc -O dev/backdrop.swift -o build/backdrop >> $L 2>&1 || { echo finished >> $L; exit 1; }
relabel() {   # the dev bundle id, so the take uses the dev build's Accessibility grant and settings
  plutil -replace CFBundleIdentifier -string $D build/GridSnap.app/Contents/Info.plist
  plutil -replace CFBundleName -string "GridSnap Dev" build/GridSnap.app/Contents/Info.plist
  plutil -replace CFBundleDisplayName -string "GridSnap Dev" build/GridSnap.app/Contents/Info.plist
  codesign --force --sign "GridSnap Dev" build/GridSnap.app >> $L 2>&1
}
install() { pkill -x GridSnap; sleep 1; rm -rf "/Applications/GridSnap Dev.app"; ditto "$1" "/Applications/GridSnap Dev.app"; open "/Applications/GridSnap Dev.app"; sleep 3; }
git worktree remove --force $W 2>/dev/null; git worktree add --detach $W upstream/master >> $L 2>&1 || { echo finished >> $L; exit 1; }
( cd $W && ./build.sh >> $L 2>&1 && relabel && rm -rf /tmp/gs-before.app && ditto build/GridSnap.app /tmp/gs-before.app && python3 - >> $L 2>&1 <<'PY'
p='Sources/Grid.swift'; s=open(p).read()
a='''        let new = bounds.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        guard new?.0 != end?.0 || new?.1 != end?.1 else { return }'''
b='''        let new = cell(e)
        guard new.0 != end?.0 || new.1 != end?.1 else { return }'''
assert s.count(a)==1; open(p,'w').write(s.replace(a,b)); print("patched: the drag keeps the edge cell")
PY
  grep -q "patched: the drag" $L && ./build.sh >> $L 2>&1 && relabel && rm -rf /tmp/gs-after.app && ditto build/GridSnap.app /tmp/gs-after.app ) || { echo "builds failed" >> $L; echo finished >> $L; exit 1; }
A=$(osascript -e 'display dialog "GridSnap clamp video: about a minute and a half, two takes. After you click Start, leave the mouse and keyboard alone until your apps come back." with title "GridSnap recording" buttons {"Cancel", "Start"} default button "Start" giving up after 420' 2>&1)
case "$A" in *"Start, gave up:false"*) ;; *) echo "cancelled: $A" >> $L; echo finished >> $L; exit 0;; esac
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null; sleep 1
open -a TextEdit; sleep 2
osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null; sleep 1
osascript -e 'tell application "TextEdit" to make new document' >/dev/null; sleep 1
swift dev/hideothers.swift >> $L 2>&1
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.finder CreateDesktop -bool false; killall Finder
build/backdrop & B=$!
install /tmp/gs-before.app; echo "== before" >> $L; build/clampdemo /tmp/clamp-before.mov >> $L 2>&1
install /tmp/gs-after.app;  echo "== after"  >> $L; build/clampdemo /tmp/clamp-after.mov  >> $L 2>&1
kill $B
defaults write com.apple.dock autohide -bool false; killall Dock
defaults write com.apple.finder CreateDesktop -bool true; killall Finder
sh dev/devbuild.sh >> $L 2>&1   # the fork's own build again
swift dev/hideothers.swift show >> $L 2>&1
echo finished >> $L
# Then, from any shell (captions from dev/label.swift, the menu bar cropped, the two takes next to each other):
#   swift dev/label.swift "0.1.13: a little past the edge, the window jumps back and the release cancels" /tmp/gs-clb.png
#   swift dev/label.swift "With the clamp: the selection stops at the edge cell and the release snaps" /tmp/gs-cla.png
#   ffmpeg -ss 1.5 -t 29 -i /tmp/clamp-before.mov -ss 1.5 -t 29 -i /tmp/clamp-after.mov -i /tmp/gs-clb.png -i /tmp/gs-cla.png -filter_complex "[0:v]fps=30,scale=1280:-2,crop=1280:ih-18:0:18[b0];[b0][2:v]overlay=(W-w)/2:24[b];[1:v]fps=30,scale=1280:-2,crop=1280:ih-18:0:18[a0];[a0][3:v]overlay=(W-w)/2:24[a];[b][a]hstack=inputs=2[v]" -map "[v]" -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart ~/Desktop/gridsnap-clamp-before-after.mp4
