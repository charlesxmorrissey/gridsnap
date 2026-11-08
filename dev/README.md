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
