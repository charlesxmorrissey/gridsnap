import AppKit
// hide (or unhide) every regular app except TextEdit and Finder so the recording shows a clean desktop
let show = CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "show"
for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular && !["com.apple.TextEdit", "com.apple.finder"].contains(a.bundleIdentifier ?? "") {
    if show { if a.isHidden { a.unhide() } } else { a.hide() }
}
