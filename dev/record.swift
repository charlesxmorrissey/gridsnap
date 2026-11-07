import AppKit
import Carbon
// Record mode: open Settings from the status item, press the "+" segment, expect panels on both displays with no window
// moving, drag on display 2's panel, expect the New preset dialog, then cancel it.
let gridPid = pid_t(CommandLine.arguments[1])!, textPid = pid_t(CommandLine.arguments[2])!
let app = AXUIElementCreateApplication(gridPid)
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var r: CFTypeRef?; AXUIElementCopyAttributeValue(e, a as CFString, &r); return r }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func find(_ e: AXUIElement, depth: Int = 0, _ test: (AXUIElement) -> Bool) -> AXUIElement? {
    if test(e) { return e }
    for k in kids(e) { if let f = find(k, depth: depth + 1, test) { return f } }
    return nil
}
func role(_ e: AXUIElement) -> String { attr(e, kAXRoleAttribute) as? String ?? "" }
func title(_ e: AXUIElement) -> String { attr(e, kAXTitleAttribute) as? String ?? attr(e, kAXDescriptionAttribute) as? String ?? "" }
func mouse(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap)
}
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == gridPid }
        .compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { abs($0.width - 480) < 2 }
}
func textFrame() -> CGRect {
    var ref: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(textPid), kAXFocusedWindowAttribute as CFString, &ref)
    let w = ref as! AXUIElement
    var f = CGRect.zero; AXValueGetValue(attr(w, kAXPositionAttribute) as! AXValue, .cgPoint, &f.origin); AXValueGetValue(attr(w, kAXSizeAttribute) as! AXValue, .cgSize, &f.size); return f
}
// open Settings… from the status item menu
let bar = attr(app, "AXExtrasMenuBar") as! AXUIElement
let item = kids(bar)[0]
AXUIElementPerformAction(item, kAXPressAction as CFString); usleep(400_000)
guard let settings = find(item, { role($0) == kAXMenuItemRole && title($0).hasPrefix("Settings") }) else { print("no Settings item"); exit(1) }
AXUIElementPerformAction(settings, kAXPressAction as CFString); usleep(1_000_000)
guard let win = (attr(app, kAXWindowsAttribute) as? [AXUIElement])?.first(where: { title($0) != "" }) else { print("no settings window"); exit(1) }
print("settings window:", title(win))
// the +/- segmented control: list candidate roles
var roles: [String] = []
_ = find(win) { e in let r = role(e); if !roles.contains(r) { roles.append(r) }; return false }
print("roles in window:", roles)
var buttons: [AXUIElement] = []
_ = find(win) { e in if role(e) == kAXButtonRole { buttons.append(e) }; return false }
print("buttons:", buttons.map { title($0) })
guard let plus = buttons.first(where: { title($0) == "+" }) else { print("no + button"); exit(1) }
let before = textFrame()
AXUIElementPerformAction(plus, kAXPressAction as CFString); usleep(1_000_000)
let ps = panels(); print("panels in record mode:", ps.count)
guard let p2 = ps.first(where: { $0.minX < 0 }) else { print("no panel on display 2"); exit(1) }
let pad: CGFloat = 28   // room around the cells; record mode has no target, so no header
func cell(_ p: CGRect, _ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: p.minX + pad + (p.width - 2 * pad) / 10 * c, y: p.minY + pad + (p.height - 2 * pad) / 10 * r) }
let s = cell(p2, 0.5, 0.5), e = cell(p2, 4.5, 4.5)
CGWarpMouseCursorPosition(s); usleep(200_000); mouse(.leftMouseDown, s)
for i in 1...10 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: s.x + (e.x - s.x) * CGFloat(i) / 10, y: s.y + (e.y - s.y) * CGFloat(i) / 10)) }
usleep(200_000); mouse(.leftMouseUp, e); usleep(1_200_000)
print("TextEdit moved during record mode:", textFrame() != before ? "YES (WRONG)" : "no (OK)")
let dialog = (attr(app, kAXWindowsAttribute) as? [AXUIElement])?.first { w in find(w, { role($0) == kAXStaticTextRole && (attr($0, kAXValueAttribute) as? String) == "New preset" }) != nil }
print("New preset dialog:", dialog != nil ? "shown (OK)" : "missing (WRONG)")
if let d = dialog, let cancel = find(d, { role($0) == kAXButtonRole && title($0) == "Cancel" }) { AXUIElementPerformAction(cancel, kAXPressAction as CFString); usleep(500_000); print("cancelled") }
if let close = attr(win, kAXCloseButtonAttribute) { AXUIElementPerformAction(close as! AXUIElement, kAXPressAction as CFString) }
print("panels at end:", panels().count)
