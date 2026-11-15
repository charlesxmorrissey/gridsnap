import AppKit
import Carbon
// One clip of display 1 for the clamp before/after video. It opens the grid three times and drags to an edge cell,
// then a little past the panel's edge, the way a fast hand overshoots: right half, left third, top right quarter.
// Takes the output .mov path. dev/clampdemo.sh runs it once per build, so the two clips line up frame for frame.
// The geometry is upstream's default panel: 480pt wide, a 10pt margin, a 52pt app header, cells in the display's aspect.
let out = CommandLine.arguments[1]
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
func mouse(_ type: CGEventType, _ p: CGPoint) { let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap) }
func glide(to p: CGPoint, steps: Int = 30) {
    let from = NSEvent.mouseLocation, top = NSScreen.screens[0].frame.maxY, start = CGPoint(x: from.x, y: top - from.y)
    for i in 1...steps { let q = CGPoint(x: start.x + (p.x - start.x) * CGFloat(i) / CGFloat(steps), y: start.y + (p.y - start.y) * CGFloat(i) / CGFloat(steps)); CGWarpMouseCursorPosition(q); mouse(.mouseMoved, q); usleep(20_000) }
}
func drag(_ a: CGPoint, _ b: CGPoint, steps: Int, pause: useconds_t) { for i in 1...steps { usleep(pause); mouse(.leftMouseDragged, CGPoint(x: a.x + (b.x - a.x) * CGFloat(i) / CGFloat(steps), y: a.y + (b.y - a.y) * CGFloat(i) / CGFloat(steps))) } }
let grid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.zerodivisionerror.gridsnap.dev").first!
let te = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first!
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == grid.processIdentifier }.compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { abs($0.width - 480) < 2 }
}
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")!
let cols = CGFloat(d.object(forKey: "cols") == nil ? 12 : d.integer(forKey: "cols")), rows = CGFloat(d.object(forKey: "rows") == nil ? 8 : d.integer(forKey: "rows"))
let vf = NSScreen.screens[0].visibleFrame, margin: CGFloat = 10, header: CGFloat = 52, cellsHigh = 480 * vf.height / vf.width - 2 * margin
func cell(_ p: CGRect, _ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: p.minX + margin + (p.width - 2 * margin) / cols * c, y: p.minY + margin + header + cellsHigh / rows * r) }
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
var pos = CGPoint(x: 100, y: 560), size = CGSize(width: 540, height: 400)   // small and off-centre, so a snap is obvious
let w = win()
AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!); AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!); AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
te.activate(); usleep(500_000)
glide(to: CGPoint(x: 1000, y: 880)); usleep(400_000)
print("start", textFrame(), "grid", Int(cols), "x", Int(rows))
let rec = Process(); rec.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); rec.arguments = ["-v", "-C", "-k", "-V", "32", "-D", "1", out]; try! rec.run()
usleep(2_000_000)
// each gesture: (name, press cell, edge cell, how far past the panel's edge the hand ends up)
let gestures: [(String, (CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat))] = [
    ("right half", (cols / 2 + 0.5, 0.5), (cols - 0.5, rows - 0.5), (45, 0)),
    ("left third", ((cols / 3).rounded() - 0.5, rows - 0.5), (0.5, 0.5), (-45, 0)),
    ("top right quarter", (cols / 2 + 0.5, rows / 2 - 0.5), (cols - 0.5, 0.5), (45, -20)),
]
for (name, a, b, over) in gestures {
    te.activate(); usleep(400_000); hotkey(); usleep(1_400_000)
    guard let p = panels().first(where: { $0.minX >= 0 }) else { print("no panel on display 1 for", name); break }
    let s = cell(p, a.0, a.1), m = cell(p, b.0, b.1)
    let e = CGPoint(x: (over.0 > 0 ? p.maxX : p.minX) + over.0, y: m.y + over.1)
    glide(to: s); usleep(400_000); mouse(.leftMouseDown, s)
    drag(s, m, steps: 40, pause: 25_000); usleep(600_000)   // to the edge cell, a beat, then on past the edge
    let atEdge = textFrame()
    drag(m, e, steps: 20, pause: 30_000); usleep(1_400_000)
    let outside = textFrame()
    mouse(.leftMouseUp, e); usleep(1_600_000)
    print(name, "| panel", p, "| at the edge cell", atEdge, "| past the edge", outside, "| after release", textFrame(), "| panels", panels().count)
}
rec.waitUntilExit()
print("recorded", out)
