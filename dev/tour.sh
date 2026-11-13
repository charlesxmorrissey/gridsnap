#!/bin/sh
# Records the settings tour to /tmp/gs-settings.mov (display 1, 60 seconds). Log: /tmp/gs-tour.log, ends with "finished".
# Needs Accessibility and Screen Recording, so run it through a terminal that holds both: open -na Ghostty --args -e "$PWD/dev/tour.sh"
# Asks before it starts, because it drives the mouse and hides the other apps, the Dock and the desktop icons for the take.
cd "$(dirname "$0")/.." || exit 1
D=com.zerodivisionerror.gridsnap.dev; L=/tmp/gs-tour.log; : > $L
mkdir -p build
swiftc -O dev/tour.swift -o build/tour >> $L 2>&1 && swiftc -O dev/backdrop.swift -o build/backdrop >> $L 2>&1 || { echo finished >> $L; exit 1; }
A=$(osascript -e 'display dialog "GridSnap settings video: about one minute. After you click Start, leave the mouse and keyboard alone until your apps come back." with title "GridSnap recording" buttons {"Cancel", "Start"} default button "Start" giving up after 420' 2>&1)
case "$A" in *"Start, gave up:false"*) ;; *) echo "cancelled: $A" >> $L; echo finished >> $L; exit 0;; esac
defaults delete $D theme 2>/dev/null; defaults delete $D numberKeys 2>/dev/null   # start from the fork's defaults: Divvy, number keys off
pkill -x GridSnap; sleep 1; open "/Applications/GridSnap Dev.app"
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null; sleep 1
open -a TextEdit; sleep 2
osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null; sleep 1
osascript -e 'tell application "TextEdit" to make new document' >/dev/null; sleep 1
swift dev/hideothers.swift >> $L 2>&1
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.finder CreateDesktop -bool false; killall Finder
build/backdrop & B=$!
sleep 3
build/tour /tmp/gs-settings.mov >> $L 2>&1; echo "driver exit $?" >> $L
kill $B
defaults write com.apple.dock autohide -bool false; killall Dock
defaults write com.apple.finder CreateDesktop -bool true; killall Finder
swift dev/hideothers.swift show >> $L 2>&1
defaults delete $D theme 2>/dev/null; defaults delete $D numberKeys 2>/dev/null
pkill -x GridSnap; sleep 1; open "/Applications/GridSnap Dev.app"
echo finished >> $L
# Then, from any shell. Captions come from dev/label.swift; the between() times are the "seg" lines in the log, moved about
# 1.4s earlier so each caption changes with the click in Settings. The crop removes the menu bar.
#   i=0; for t in "Theme: Divvy" "Divvy, number keys on" "Theme: Default, number keys on" "Default, number keys off" "Back to Divvy"; do i=$((i+1)); swift dev/label.swift "$t" /tmp/gs-lab$i.png; done
#   ffmpeg -t 57.6 -i /tmp/gs-settings.mov -i /tmp/gs-lab1.png -i /tmp/gs-lab2.png -i /tmp/gs-lab3.png -i /tmp/gs-lab4.png -i /tmp/gs-lab5.png -filter_complex "[0:v]scale=1920:-2,crop=1920:ih-26:0:26[v];[1:v]scale=iw*0.6:-1[l1];[2:v]scale=iw*0.6:-1[l2];[3:v]scale=iw*0.6:-1[l3];[4:v]scale=iw*0.6:-1[l4];[5:v]scale=iw*0.6:-1[l5];[v][l1]overlay=1400:790:enable='between(t,0,14.2)'[a];[a][l2]overlay=1400:790:enable='between(t,14.2,25.2)'[b];[b][l3]overlay=1400:790:enable='between(t,25.2,36.6)'[c];[c][l4]overlay=1400:790:enable='between(t,36.6,49.2)'[d];[d][l5]overlay=1400:790:enable='gte(t,49.2)'" -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart ~/Desktop/gridsnap-settings-tour.mp4
