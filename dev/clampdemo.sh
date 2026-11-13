#!/bin/sh
# Records the clamp before/after clips to /tmp/clamp-before.mov and /tmp/clamp-after.mov (display 1, 15 seconds each).
# Log: /tmp/gs-clampdemo.log, ends with "finished". The "before" take needs upstream's behavior, so this patches
# GridView.track in Sources/Grid.swift to cancel outside the panel, builds, restores the file, records, then builds the
# real source again for the "after" take. If track() changed, the patch stops with an assertion instead of recording.
# Needs Accessibility and Screen Recording: open -na Ghostty --args -e "$PWD/dev/clampdemo.sh"
cd "$(dirname "$0")/.." || exit 1
D=com.zerodivisionerror.gridsnap.dev; L=/tmp/gs-clampdemo.log; : > $L
mkdir -p build
swiftc -O dev/clampdemo.swift -o build/clampdemo >> $L 2>&1 && swiftc -O dev/backdrop.swift -o build/backdrop >> $L 2>&1 || { echo finished >> $L; exit 1; }
A=$(osascript -e 'display dialog "GridSnap clamp video: about a minute and a half, two takes with a rebuild between them. After you click Start, leave the mouse and keyboard alone until your apps come back." with title "GridSnap recording" buttons {"Cancel", "Start"} default button "Start" giving up after 420' 2>&1)
case "$A" in *"Start, gave up:false"*) ;; *) echo "cancelled: $A" >> $L; echo finished >> $L; exit 0;; esac
defaults delete $D theme 2>/dev/null; defaults delete $D numberKeys 2>/dev/null
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null; sleep 1
open -a TextEdit; sleep 2
osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null; sleep 1
osascript -e 'tell application "TextEdit" to make new document' >/dev/null; sleep 1
swift dev/hideothers.swift >> $L 2>&1
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.finder CreateDesktop -bool false; killall Finder
build/backdrop & B=$!
cp Sources/Grid.swift /tmp/gs-Grid.keep
python3 - >> $L 2>&1 <<'PY'
p='Sources/Grid.swift'; s=open(p).read()
a='''        let new = cell(e)
        guard new.0 != end?.0 || new.1 != end?.1 else { return }'''
b='''        let new = bounds.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        guard new?.0 != end?.0 || new?.1 != end?.1 else { return }'''
assert s.count(a)==1; open(p,'w').write(s.replace(a,b)); print("patched to the old cancel behavior")
PY
if grep -q "patched to the old" $L; then
  sh dev/devbuild.sh >> $L 2>&1
  cp /tmp/gs-Grid.keep Sources/Grid.swift; echo "source restored" >> $L
  sleep 3
  echo "== before" >> $L; build/clampdemo /tmp/clamp-before.mov >> $L 2>&1
  sh dev/devbuild.sh >> $L 2>&1; sleep 3
  echo "== after" >> $L; build/clampdemo /tmp/clamp-after.mov >> $L 2>&1
fi
kill $B
defaults write com.apple.dock autohide -bool false; killall Dock
defaults write com.apple.finder CreateDesktop -bool true; killall Finder
swift dev/hideothers.swift show >> $L 2>&1
echo finished >> $L
# Then, from any shell (captions from dev/label.swift, the menu bar cropped, the two takes one after the other):
#   swift dev/label.swift "Before: past the panel edge the window jumps back, and the release cancels" /tmp/gs-clb.png
#   swift dev/label.swift "After: the selection stops at the edge cell, and the release snaps" /tmp/gs-cla.png
#   ffmpeg -ss 1.5 -t 12.5 -i /tmp/clamp-before.mov -ss 1.5 -t 12.5 -i /tmp/clamp-after.mov -i /tmp/gs-clb.png -i /tmp/gs-cla.png -filter_complex "[2:v]scale=iw*0.6:-1[lb];[3:v]scale=iw*0.6:-1[la];[0:v]fps=30,scale=1920:-2,crop=1920:ih-26:0:26[b0];[b0][lb]overlay=(W-w)/2:60[b];[1:v]fps=30,scale=1920:-2,crop=1920:ih-26:0:26[a0];[a0][la]overlay=(W-w)/2:60[a];[b][a]concat=n=2:v=1[v]" -map "[v]" -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart ~/Desktop/gridsnap-clamp-before-after.mp4
