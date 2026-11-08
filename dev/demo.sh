#!/bin/sh
cd /Users/charlesxmorrissey/Projects/sandbox/gridsnap
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null; sleep 1
open -a TextEdit; sleep 2
osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null; sleep 1
osascript -e 'tell application "TextEdit" to make new document'; sleep 1
osascript -e 'tell application "TextEdit" to count windows'
swift dev/hideothers.swift
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.finder CreateDesktop -bool false; killall Finder
sleep 2
swift dev/demo.swift > /tmp/demo2.log 2>&1
echo "exit $?" >> /tmp/demo2.log
defaults write com.apple.dock autohide -bool false; killall Dock
defaults write com.apple.finder CreateDesktop -bool true; killall Finder
swift dev/hideothers.swift show
echo "restored" >> /tmp/demo2.log
# Then, from any shell:
#   ffmpeg -i /tmp/demo-d2.mov -i /tmp/demo-d1.mov -filter_complex "[0:v]scale=1920:-2,crop=1920:ih-26:0:26[a];[1:v]scale=1920:-2,crop=1920:ih-26:0:26,drawbox=x=0:y=0:w=580:h=400:color=black:t=fill[b];[a][b]hstack" -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart ~/Desktop/gridsnap-divvy-style.mov
# (the drawbox hides the desktop widgets at the top left of display 1; the crop drops the menu bar)
