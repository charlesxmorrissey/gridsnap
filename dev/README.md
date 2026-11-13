# Dev scripts

Scripts for building and driving the app on this Mac. They assume two displays, the main one on the right, and the
`GridSnap Dev` self-signed certificate in the login keychain so the Accessibility grant survives rebuilds.

`devbuild.sh` builds the app and relabels it as `com.zerodivisionerror.gridsnap.dev` so it keeps its own settings and
Accessibility grant next to the Homebrew install. Run the result with `open build/GridSnap.app`.

The Swift files drive the running dev build with synthetic events. Each takes the GridSnap pid and the TextEdit pid:
`swift dev/checks.swift $(pgrep -x GridSnap) $(pgrep -x TextEdit)`. `gridtest.swift` opens the grid and drags or uses
the keyboard across displays, `checks.swift` covers presets, undo and ghosts, `record.swift` drives record mode from
Settings, `clamp.swift` releases a drag outside the panel, `menu.swift` reads the status menu to tell whether the
build is trusted. `demo.sh` records the two-display demo video: it gives TextEdit a fresh document, hides other apps, the Dock and desktop
icons, runs `demo.swift` (which records both displays with `screencapture -v` while it drives the grid: open, cursor
hand-off, a drag to each display, the clamp), then restores everything; the ffmpeg line in its comment stitches the
two clips. Run it through a terminal that holds the Accessibility and Screen Recording grants.

`tour.sh` and `clampdemo.sh` record the two videos for the upstream discussion. `tour.sh` records the Theme popup and
the "Number keys on the grid" checkbox with the Settings window in view. `clampdemo.sh` records one drag past the panel
edge two times: one time on a build with upstream's cancel behavior, and one time on the current build. Each script
shows a Start dialog first. After you click Start, do not touch the mouse or the keyboard until your apps come back.
Each script draws `backdrop.swift` behind the windows. The backdrop hides the wallpaper and the desktop widgets, which
can show reminders and calendar entries. Start each script through a terminal that holds the two grants, for example
`open -na Ghostty --args -e "$PWD/dev/tour.sh"`. Each script writes a log in `/tmp` that ends with `finished`. The
comment at the end of each script gives the ffmpeg command that adds the captions and writes the final file. Before you
share a video, look at the top left corner of the display through the full clip, because that is where the widgets are.
