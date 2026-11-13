import AppKit
import Carbon
// One clip of display 1 for the clamp before/after video: open the grid, drag from inside the panel to its last cell,
// then far outside it, hold, release. Takes the output .mov path. dev/clampdemo.sh runs it once per build.
let out = CommandLine.arguments[1]
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
func mouse(_ type: CGEventType, _ p: CGPoint) { let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap) }
func glide(to p: CGPoint, steps: Int = 30) {
    let from = NSEvent.mouseLocation, top = NSScreen.screens[0].frame.maxY, start = CGPoint(x: from.x, y: top - from.y)
    for i in 1...steps { let q = CGPoint(x: start.x + (p.x - start.x) * CGFloat(i) / CGFloat(steps), y: start.y + (p.y - start.y) * CGFloat(i) / CGFloat(steps)); CGWarpMouseCursorPosition(q); mouse(.mouseMoved, q); usleep(20_000) }
}
let grid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.zerodivisionerror.gridsnap.dev").first!
let te = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first!
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == grid.processIdentifier }.compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { abs($0.width - 320) < 2 }
}
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")!
let cols = CGFloat(d.object(forKey: "cols") == nil ? 12 : d.integer(forKey: "cols")), rows = CGFloat(d.object(forKey: "rows") == nil ? 8 : d.integer(forKey: "rows"))
let pad: CGFloat = 20, header: CGFloat = 62
func cell(_ p: CGRect, _ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: p.minX + pad + (p.width - 2 * pad) / cols * c, y: p.minY + header + (p.height - pad - header) / rows * r) }
func win() -> AXUIElement { var ref: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(te.processIdentifier), kAXFocusedWindowAttribute as CFString, &ref); return ref as! AXUIElement }
func textFrame() -> CGRect {
    let w = win(); var p: CFTypeRef?, s: CFTypeRef?
    AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &p); AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &s)
    var f = CGRect.zero; AXValueGetValue(p as! AXValue, .cgPoint, &f.origin); AXValueGetValue(s as! AXValue, .cgSize, &f.size); return f
}
te.activate(); usleep(500_000)
var sub: CFTypeRef?; AXUIElementCopyAttributeValue(win(), kAXSubroleAttribute as CFString, &sub)
print("target window subrole:", sub as? String ?? "nil")
guard (sub as? String) == kAXStandardWindowSubrole else { print("not a document window"); exit(1) }
var pos = CGPoint(x: 100, y: 560), size = CGSize(width: 540, height: 400)   // small and off-centre, so the snap is obvious
let w = win()
AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!); AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!); AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
te.activate(); usleep(500_000)
glide(to: CGPoint(x: 1000, y: 800)); usleep(400_000)
print("before", textFrame())
let rec = Process(); rec.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); rec.arguments = ["-v", "-V", "15", "-D", "1", out]; try! rec.run()
usleep(2_000_000)
te.activate(); usleep(400_000); hotkey(); usleep(1_600_000)
guard let p1 = panels().first(where: { $0.minX >= 0 }) else { print("no panel on display 1"); rec.terminate(); exit(1) }
let s = cell(p1, cols - 2.5, 1.5), e = CGPoint(x: p1.maxX + 260, y: p1.maxY + 200)
glide(to: s); usleep(500_000); mouse(.leftMouseDown, s)
let m = cell(p1, cols - 0.5, rows - 0.5)   // first to the last cell inside the panel, pause, then on past the edge
for i in 1...40 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: s.x + (m.x - s.x) * CGFloat(i) / 40, y: s.y + (m.y - s.y) * CGFloat(i) / 40)) }
usleep(900_000); print("at the last cell", textFrame())
for i in 1...40 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: m.x + (e.x - m.x) * CGFloat(i) / 40, y: m.y + (e.y - m.y) * CGFloat(i) / 40)) }
usleep(1_500_000); print("while outside", textFrame())
mouse(.leftMouseUp, e); usleep(1_500_000)
print("after release", textFrame(), "panels", panels().count)
rec.waitUntilExit()
print("recorded", out)
