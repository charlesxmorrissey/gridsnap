# Repo rules

Graduated patterns for this repo. Each comment carries the learning id and hit count; `akt learn show <id>` lists the stories.

- Automation that takes over the user's mouse, keyboard or screen (recordings, synthetic-event drivers) must not start on its own while the user is at the machine — open with a dialog the user clicks (osascript display dialog), so their click is the go and a collision can't ruin the take or capture their windows
  <!-- akt: gate-mouse-driving-automation-on-a-start-dialog | 3 hits | gridsnap/2026-11-07-grid-on-every-display-divvy-style-pr-upstream-and-fork-iteration, gridsnap/2026-11-15-0-1-14-themes-divvy-becomes-a-theme-file-the-fork-adds-hover-and-layout-to-the-format -->
