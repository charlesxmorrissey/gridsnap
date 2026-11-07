import AppKit
// Read the dev build's status-item menu titles: a "Grant Accessibility…" item means it is not trusted yet.
let pid = pid_t(CommandLine.arguments[1])!
let app = AXUIElementCreateApplication(pid)
var bar: CFTypeRef?
print("extras menubar:", AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &bar).rawValue)
guard let bar else { exit(0) }
var kids: CFTypeRef?
AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &kids)
for item in (kids as? [AXUIElement]) ?? [] {
    AXUIElementPerformAction(item, kAXPressAction as CFString); usleep(300_000)
    var menu: CFTypeRef?; AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &menu)
    for m in (menu as? [AXUIElement]) ?? [] {
        var items: CFTypeRef?; AXUIElementCopyAttributeValue(m, kAXChildrenAttribute as CFString, &items)
        for i in (items as? [AXUIElement]) ?? [] { var t: CFTypeRef?; AXUIElementCopyAttributeValue(i, kAXTitleAttribute as CFString, &t); print("  item:", t as? String ?? "-") }
    }
    AXUIElementPerformAction(item, kAXCancelAction as CFString)
    let d = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!; d.post(tap: .cghidEventTap)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)!; u.post(tap: .cghidEventTap)
}
