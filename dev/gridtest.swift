import AppKit
import Carbon
// Drive the running GridSnap: press its grid hotkey, then report its on-screen windows and the target window frame.
let gridPid = pid_t(CommandLine.arguments[1])!, textPid = pid_t(CommandLine.arguments[2])!
let mode = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "open"
func post(_ key: CGKeyCode, _ flags: CGEventFlags = []) {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)!, u = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)!
    d.flags = flags; u.flags = flags; d.post(tap: .cghidEventTap); usleep(50_000); u.post(tap: .cghidEventTap)
}
func click(_ p: CGPoint, drag to: CGPoint? = nil) {   // CG coordinates, top-left origin
    CGWarpMouseCursorPosition(p); usleep(100_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
    if let to { for i in 1...10 { let q = CGPoint(x: p.x + (to.x - p.x) * CGFloat(i) / 10, y: p.y + (to.y - p.y) * CGFloat(i) / 10); usleep(40_000)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: q, mouseButton: .left)!.post(tap: .cghidEventTap) } }
    usleep(100_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: to ?? p, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == gridPid }
        .compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { $0.width > 100 }
}
func textFrame() -> CGRect {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(AXUIElementCreateApplication(textPid), kAXFocusedWindowAttribute as CFString, &ref)
    let win = ref as! AXUIElement
    var p: CFTypeRef?, s: CFTypeRef?
    AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &p); AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &s)
    var f = CGRect.zero; AXValueGetValue(p as! AXValue, .cgPoint, &f.origin); AXValueGetValue(s as! AXValue, .cgSize, &f.size); return f
}
// The dev build's hotkey is ⇧⌘Space, pressed as real modifier keys. Grid size comes from the dev build's defaults (cols/rows, 10 when unset).
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")
let nc = CGFloat(d?.object(forKey: "cols") == nil ? 10 : d!.integer(forKey: "cols")), nr = CGFloat(d?.object(forKey: "rows") == nil ? 10 : d!.integer(forKey: "rows"))
NSRunningApplication(processIdentifier: textPid)!.activate()
usleep(400_000)
print("TextEdit before:", textFrame())
switch mode {
case "open":
    CGWarpMouseCursorPosition(CGPoint(x: 960, y: 540)); usleep(100_000)   // cursor on the primary display
    hotkey(); usleep(900_000)
    let p = panels(); print("GridSnap panels on screen:", p.count); p.forEach { print("  ", $0) }
    post(CGKeyCode(kVK_Escape)); usleep(1_000_000)
    print("after esc, panels:", panels().count)
case "drag":   // open, then drag the left half of the second display's grid (display 2 is at x -1920...0)
    CGWarpMouseCursorPosition(CGPoint(x: 960, y: 540)); usleep(100_000)
    hotkey(); usleep(900_000)
    guard let p2 = panels().first(where: { $0.minX < 0 }) else { print("no panel on display 2"); exit(1) }
    print("panel on display 2:", p2)
    let pad: CGFloat = 20, header: CGFloat = 62, cw = (p2.width - 2 * pad) / nc, ch: CGFloat = 195 / nr   // room around the cells, app icon and name above them; the cell area is a fixed 195pt high
    click(CGPoint(x: p2.minX + pad + cw * 0.5, y: p2.minY + header + ch * 0.5), drag: CGPoint(x: p2.minX + pad + cw * (nc / 2 - 0.5), y: p2.minY + header + ch * (nr - 0.5)))
    usleep(600_000)
    print("after drag, panels:", panels().count)
    let f = textFrame(); print("TextEdit after:", f)
    print(abs(f.minX - -1920) < 2 && abs(f.width - 960) < 3 && abs(f.minY - 30) < 3 && abs(f.height - 1050) < 3 && panels().isEmpty ? "OK: left half of display 2" : "WRONG")
case "tab":   // open, Tab to the other display, Return: with no selection there nothing moves; arrows then Return snap there
    CGWarpMouseCursorPosition(CGPoint(x: 960, y: 540)); usleep(100_000)
    hotkey(); usleep(900_000)
    print("panels:", panels().count)
    post(CGKeyCode(kVK_Tab)); usleep(300_000)
    print("after tab, panels:", panels().count)
    post(CGKeyCode(kVK_LeftArrow)); usleep(300_000)   // whole display 2, then shrink it
    post(CGKeyCode(kVK_LeftArrow), [.maskShift]); usleep(300_000)
    print("mid-preview TextEdit:", textFrame())
    post(CGKeyCode(kVK_Return)); usleep(600_000)
    print("after return, panels:", panels().count)
    print("TextEdit after:", textFrame())
default: break
}
