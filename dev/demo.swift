import AppKit
import Carbon
// Two-display demo for the divvy-style PR: header, dim + cursor hand-off, drag across displays both ways, clamp at the edge.
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
func mouse(_ type: CGEventType, _ p: CGPoint) { let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap) }
func glide(to p: CGPoint, steps: Int = 30) {
    let from = NSEvent.mouseLocation, top = NSScreen.screens[0].frame.maxY, start = CGPoint(x: from.x, y: top - from.y)
    for i in 1...steps { let q = CGPoint(x: start.x + (p.x - start.x) * CGFloat(i) / CGFloat(steps), y: start.y + (p.y - start.y) * CGFloat(i) / CGFloat(steps)); CGWarpMouseCursorPosition(q); mouse(.mouseMoved, q); usleep(20_000) }
}
func drag(_ p: CGPoint, to: CGPoint) {
    glide(to: p); usleep(400_000); mouse(.leftMouseDown, p)
    for i in 1...30 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: p.x + (to.x - p.x) * CGFloat(i) / 30, y: p.y + (to.y - p.y) * CGFloat(i) / 30)) }
    usleep(500_000); mouse(.leftMouseUp, to)
}
let grid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.zerodivisionerror.gridsnap.dev").first!
let te = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first!
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == grid.processIdentifier }.compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { abs($0.width - 320) < 2 }
}
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")!
let cols = CGFloat(d.object(forKey: "cols") == nil ? 10 : d.integer(forKey: "cols")), rows = CGFloat(d.object(forKey: "rows") == nil ? 10 : d.integer(forKey: "rows"))
let pad: CGFloat = 20, header: CGFloat = 62
func cell(_ p: CGRect, _ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: p.minX + pad + (p.width - 2 * pad) / cols * c, y: p.minY + header + (p.height - pad - header) / rows * r) }
// place TextEdit's document window on display 1 (never the Open dialog)
te.activate(); usleep(500_000)
var ref: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(te.processIdentifier), kAXFocusedWindowAttribute as CFString, &ref)
var win = ref as! AXUIElement
var sub: CFTypeRef?; AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &sub)
if (sub as? String) != kAXStandardWindowSubrole { key(CGKeyCode(kVK_Escape), down: true, []); key(CGKeyCode(kVK_Escape), down: false, []); usleep(600_000); AXUIElementCopyAttributeValue(AXUIElementCreateApplication(te.processIdentifier), kAXFocusedWindowAttribute as CFString, &ref); win = ref as! AXUIElement; AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &sub) }
print("target window subrole:", sub as? String ?? "nil")
var pos = CGPoint(x: 560, y: 300), size = CGSize(width: 900, height: 560)
AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!); AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!); AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
te.activate(); usleep(500_000)
glide(to: CGPoint(x: 1000, y: 650)); usleep(500_000)
// recordings
var recs: [Process] = []
for n in 1...2 { let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); t.arguments = ["-v", "-V", "34", "-D", "\(n)", "/tmp/demo-d\(n).mov"]; try! t.run(); recs.append(t) }
usleep(2_000_000)
// 1. open: both panels, display 1 bright
te.activate(); usleep(400_000); hotkey(); usleep(1_800_000)
guard let p1 = panels().first(where: { $0.minX >= 0 }), let p2 = panels().first(where: { $0.minX < 0 }) else { print("need two panels"); recs.forEach { $0.terminate() }; exit(1) }
// 2. hand-off: glide to display 2's panel, it brightens and display 1 dims
glide(to: CGPoint(x: p2.midX, y: p2.midY - 60), steps: 45); usleep(1_500_000)
// 3. drag the left half of display 2
drag(cell(p2, 0.5, 0.5), to: cell(p2, cols / 2 - 0.5, rows - 0.5)); usleep(1_800_000)
// 4. open again (window on display 2 now, so display 2 is bright), glide back, drag the right half of display 1
te.activate(); usleep(400_000); hotkey(); usleep(1_500_000)
glide(to: CGPoint(x: p1.midX, y: p1.midY - 60), steps: 45); usleep(1_200_000)
drag(cell(p1, cols / 2 + 0.5, 0.5), to: cell(p1, cols - 0.5, rows - 0.5)); usleep(1_800_000)
// 5. clamp: drag from inside display 1's panel to far outside and release
te.activate(); usleep(400_000); hotkey(); usleep(1_500_000)
drag(cell(p1, cols - 1.5, 1.5), to: CGPoint(x: p1.maxX + 260, y: p1.maxY + 200)); usleep(1_800_000)   // clamps to the last two columns, rows 1 to the end
print("panels at end:", panels().count)
recs.forEach { $0.waitUntilExit() }
print("recorded")
