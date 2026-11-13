import AppKit
import Carbon
// Settings tour on display 1 for a video: Divvy theme, number keys on, Default theme, number keys off, back to Divvy.
// Takes the output .mov path. Clicks the real controls in the Settings window, which stays open on the right.
// Prints "seg <seconds> <name>" at each step for caption timing. Run it through dev/tour.sh.
let out = CommandLine.arguments[1]
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
func mouse(_ type: CGEventType, _ p: CGPoint) { let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap) }
func glide(to p: CGPoint, steps: Int = 35) {
    let from = NSEvent.mouseLocation, top = NSScreen.screens[0].frame.maxY, start = CGPoint(x: from.x, y: top - from.y)
    for i in 1...steps { let q = CGPoint(x: start.x + (p.x - start.x) * CGFloat(i) / CGFloat(steps), y: start.y + (p.y - start.y) * CGFloat(i) / CGFloat(steps)); CGWarpMouseCursorPosition(q); mouse(.mouseMoved, q); usleep(20_000) }
}
func click(_ p: CGPoint) { glide(to: p); usleep(350_000); mouse(.leftMouseDown, p); usleep(90_000); mouse(.leftMouseUp, p) }
func drag(_ p: CGPoint, to: CGPoint) {
    glide(to: p); usleep(400_000); mouse(.leftMouseDown, p)
    for i in 1...40 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: p.x + (to.x - p.x) * CGFloat(i) / 40, y: p.y + (to.y - p.y) * CGFloat(i) / 40)) }
    usleep(600_000); mouse(.leftMouseUp, to)
}
let grid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.zerodivisionerror.gridsnap.dev").first!
let te = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first!
let gapp = AXUIElementCreateApplication(grid.processIdentifier)
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var r: CFTypeRef?; AXUIElementCopyAttributeValue(e, a as CFString, &r); return r }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func find(_ e: AXUIElement, _ test: (AXUIElement) -> Bool) -> AXUIElement? { if test(e) { return e }; for k in kids(e) { if let f = find(k, test) { return f } }; return nil }
func role(_ e: AXUIElement) -> String { attr(e, kAXRoleAttribute) as? String ?? "" }
func title(_ e: AXUIElement) -> String { attr(e, kAXTitleAttribute) as? String ?? attr(e, kAXDescriptionAttribute) as? String ?? "" }
func frame(_ w: AXUIElement) -> CGRect { var f = CGRect.zero; AXValueGetValue(attr(w, kAXPositionAttribute) as! AXValue, .cgPoint, &f.origin); AXValueGetValue(attr(w, kAXSizeAttribute) as! AXValue, .cgSize, &f.size); return f }
func place(_ w: AXUIElement, _ p: CGPoint, _ s: CGSize?) {
    var p = p; AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
    if var s = s { AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!); AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!) }
}
func fail(_ m: String) -> Never { print("FAIL:", m); exit(1) }
func panel() -> CGRect {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let ps = info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == grid.processIdentifier }.compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { (abs($0.width - 320) < 2 || abs($0.width - 480) < 2) && $0.minX >= 0 }
    guard let p = ps.first else { fail("no grid panel on display 1") }
    return p
}
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")!
let cols = CGFloat(d.object(forKey: "cols") == nil ? 12 : d.integer(forKey: "cols")), rows = CGFloat(d.object(forKey: "rows") == nil ? 8 : d.integer(forKey: "rows"))
struct Look { var pad: CGFloat, list: CGFloat; var header: CGFloat { pad + 42 } }
func cell(_ p: CGRect, _ k: Look, _ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: p.minX + k.pad + (p.width - 2 * k.pad) / cols * c, y: p.minY + k.header + (p.height - k.pad - k.header - k.list) / rows * r) }
func entry(_ p: CGRect, _ k: Look, _ i: Int) -> CGPoint { let w = (p.width - 2 * k.pad) / 3; return CGPoint(x: p.minX + k.pad + (CGFloat(i % 3) + 0.35) * w, y: p.maxY - k.pad - CGFloat(2 - i / 3) * 20 - 10) }   // nine presets, three rows
func teWin() -> AXUIElement { guard let w = attr(AXUIElementCreateApplication(te.processIdentifier), kAXFocusedWindowAttribute) else { fail("no TextEdit window") }; return w as! AXUIElement }
func openGrid() -> CGRect { te.activate(); usleep(500_000); hotkey(); usleep(1_500_000); return panel() }

// stage: TextEdit document bottom-left, Settings on the right
te.activate(); usleep(500_000)
guard (attr(teWin(), kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole else { fail("TextEdit front window is not a document") }
place(teWin(), CGPoint(x: 100, y: 560), CGSize(width: 540, height: 400))
let bar = attr(gapp, "AXExtrasMenuBar") as! AXUIElement
let item = kids(bar)[0]
AXUIElementPerformAction(item, kAXPressAction as CFString); usleep(400_000)
guard let settings = find(item, { role($0) == kAXMenuItemRole && title($0).hasPrefix("Settings") }) else { fail("no Settings item") }
AXUIElementPerformAction(settings, kAXPressAction as CFString); usleep(1_200_000)
guard let win = (attr(gapp, kAXWindowsAttribute) as? [AXUIElement])?.first(where: { title($0) != "" }) else { fail("no settings window") }
place(win, CGPoint(x: 1400, y: 140), nil); usleep(400_000)
guard let box = find(win, { role($0) == kAXCheckBoxRole }), let pop = find(win, { role($0) == kAXPopUpButtonRole }) else { fail("settings controls missing") }
print("settings at", frame(win), "checkbox", attr(box, kAXValueAttribute) ?? "?" as CFString, "theme", attr(pop, kAXValueAttribute) ?? "?" as CFString)
func toggleBox() { grid.activate(); usleep(400_000); let f = frame(box); click(CGPoint(x: f.minX + 10, y: f.midY)); usleep(900_000) }
func pick(_ name: String) {
    grid.activate(); usleep(400_000); let f = frame(pop); click(CGPoint(x: f.midX, y: f.midY)); usleep(800_000)
    guard let m = find(pop, { role($0) == kAXMenuItemRole && title($0) == name }) else { fail("no menu item \(name)") }
    let mf = frame(m); click(CGPoint(x: mf.midX, y: mf.midY)); usleep(900_000)
    print("theme now", attr(pop, kAXValueAttribute) ?? "?" as CFString)
}
te.activate(); usleep(400_000); glide(to: CGPoint(x: 1100, y: 880)); usleep(400_000)

let rec = Process(); rec.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); rec.arguments = ["-v", "-V", "60", "-D", "1", out]; try! rec.run()
let t0 = Date(); func mark(_ s: String) { print(String(format: "seg %.2f %@", Date().timeIntervalSince(t0), s)) }
usleep(2_000_000)
let divvy = Look(pad: 20, list: 0), divvyList = Look(pad: 20, list: 68), glassList = Look(pad: 10, list: 68), glass = Look(pad: 10, list: 0)
// 1. Divvy theme, no list: hover, then drag the left half
mark("divvy")
var p = openGrid()
glide(to: cell(p, divvy, 0.5, 0.5)); glide(to: cell(p, divvy, 4.5, 2.5), steps: 60); glide(to: cell(p, divvy, 1.5, 4.5), steps: 50); usleep(300_000)
drag(cell(p, divvy, 0.5, 0.5), to: cell(p, divvy, 2.5, 5.5)); usleep(1_600_000)
// 2. number keys on: the list appears, click "Left two thirds"
toggleBox(); mark("divvy-list")
p = openGrid(); print("panel", p); usleep(1_300_000)
click(entry(p, divvyList, 3)); usleep(1_700_000)
// 3. Default theme with the list: drag the top-left quarter
pick("Default"); mark("default-list")
p = openGrid(); print("panel", p); usleep(1_300_000)
drag(cell(p, glassList, 0.5, 0.5), to: cell(p, glassList, 2.5, 2.5)); usleep(1_600_000)
// 4. number keys off in the Default theme: drag the left third
toggleBox(); mark("default")
p = openGrid(); print("panel", p); usleep(1_200_000)
drag(cell(p, glass, 0.5, 0.5), to: cell(p, glass, 1.5, 5.5)); usleep(1_600_000)
// 5. back to Divvy
pick("Divvy"); mark("divvy-again")
p = openGrid(); print("panel", p); usleep(1_800_000)
key(CGKeyCode(kVK_Escape), down: true, []); key(CGKeyCode(kVK_Escape), down: false, []); usleep(1_200_000)
mark("end")
rec.waitUntilExit()   // screencapture only writes the file when its own timer ends
if let c = attr(win, kAXCloseButtonAttribute) { AXUIElementPerformAction(c as! AXUIElement, kAXPressAction as CFString) }
print("recorded", out)
