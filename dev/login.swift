import AppKit
// Read or set the "Launch at Login" menu item of the running GridSnap with the given pid: args <pid> <on|off|read>
let pid = pid_t(CommandLine.arguments[1])!, want = CommandLine.arguments[2]
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var r: CFTypeRef?; AXUIElementCopyAttributeValue(e, a as CFString, &r); return r }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = AXUIElementCreateApplication(pid)
let bar = attr(app, "AXExtrasMenuBar") as! AXUIElement, item = kids(bar)[0]
AXUIElementPerformAction(item, kAXPressAction as CFString); usleep(400_000)
var target: AXUIElement?
for m in kids(item) { for i in kids(m) where (attr(i, kAXTitleAttribute) as? String) == "Launch at Login" { target = i } }
guard let t = target else { print("no item"); exit(1) }
let on = (attr(t, kAXMenuItemMarkCharAttribute) as? String)?.isEmpty == false
print("launch at login was", on ? "on" : "off")
if (want == "on" && !on) || (want == "off" && on) { AXUIElementPerformAction(t, kAXPressAction as CFString); usleep(400_000); print("toggled") }
else { AXUIElementPerformAction(item, kAXCancelAction as CFString); let d = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!; d.post(tap: .cghidEventTap); let u = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)!; u.post(tap: .cghidEventTap) }
