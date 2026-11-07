import AppKit
import Carbon
// Drag from inside display 2's panel to far outside it and release: the selection should clamp to the edge and snap,
// not cancel. Start cell (1,1) -> release 400pt left of and below the panel => expect columns 0-1 and rows 1 to the last
// of display 2. Grid size comes from the dev build's defaults (cols/rows, 10 when unset).
let gridPid = pid_t(CommandLine.arguments[1])!, textPid = pid_t(CommandLine.arguments[2])!
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000) }
func hotkey() { key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, []) }
func mouse(_ type: CGEventType, _ p: CGPoint) { let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap) }
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == gridPid }.compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { abs($0.width - 320) < 2 }
}
func textFrame() -> CGRect {
    var ref: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(textPid), kAXFocusedWindowAttribute as CFString, &ref)
    let w = ref as! AXUIElement; var p: CFTypeRef?, s: CFTypeRef?
    AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &p); AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &s)
    var f = CGRect.zero; AXValueGetValue(p as! AXValue, .cgPoint, &f.origin); AXValueGetValue(s as! AXValue, .cgSize, &f.size); return f
}
NSRunningApplication(processIdentifier: textPid)!.activate(); usleep(400_000)
print("before", textFrame())
CGWarpMouseCursorPosition(CGPoint(x: 960, y: 700)); usleep(200_000)
hotkey(); usleep(900_000)
guard let p2 = panels().first(where: { $0.minX < 0 }) else { print("no panel on display 2"); exit(1) }
let pad: CGFloat = 20, header: CGFloat = 64   // room around the cells, app icon and name above them
let d = UserDefaults(suiteName: "com.zerodivisionerror.gridsnap.dev")
let nc = CGFloat(d?.object(forKey: "cols") == nil ? 10 : d!.integer(forKey: "cols")), nr = CGFloat(d?.object(forKey: "rows") == nil ? 10 : d!.integer(forKey: "rows"))
let cw = (p2.width - 2 * pad) / nc, ch = (p2.height - pad - header) / nr
let s = CGPoint(x: p2.minX + pad + cw * 1.5, y: p2.minY + header + ch * 1.5), e = CGPoint(x: p2.minX - 400, y: p2.maxY + 300)
CGWarpMouseCursorPosition(s); usleep(200_000); mouse(.leftMouseDown, s)
for i in 1...20 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: s.x + (e.x - s.x) * CGFloat(i) / 20, y: s.y + (e.y - s.y) * CGFloat(i) / 20)) }
usleep(300_000); let mid = textFrame(); mouse(.leftMouseUp, e); usleep(900_000)
let f = textFrame()
print("while outside", mid, " after release", f, "panels", panels().count)
let okX = abs(f.minX - -1920) < 2 && abs(f.width - 1920 * 2 / nc) < 3, okY = abs(f.minY - (30 + 1050 / nr)) < 3 && abs(f.height - 1050 * (nr - 1) / nr) < 3
print(okX && okY && panels().isEmpty ? "OK: clamped to columns 0-1, rows 1-\(Int(nr) - 1) of a \(Int(nc))x\(Int(nr)) grid on display 2 and snapped" : "WRONG")
