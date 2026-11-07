import AppKit
import Carbon
let gridPid = pid_t(CommandLine.arguments[1])!, textPid = pid_t(CommandLine.arguments[2])!
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000)
}
func chord(_ k: CGKeyCode, _ mods: [(CGKeyCode, CGEventFlags)]) {   // modifiers down first, released last
    var f: CGEventFlags = []
    for (m, fl) in mods { f.insert(fl); key(m, down: true, f) }
    key(k, down: true, f); key(k, down: false, f)
    for (m, fl) in mods.reversed() { f.remove(fl); key(m, down: false, f) }
}
let ctrlOpt: [(CGKeyCode, CGEventFlags)] = [(CGKeyCode(kVK_Control), .maskControl), (CGKeyCode(kVK_Option), .maskAlternate)]
let shiftCmd: [(CGKeyCode, CGEventFlags)] = [(CGKeyCode(kVK_Shift), .maskShift), (CGKeyCode(kVK_Command), .maskCommand)]
func mouse(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap)
}
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == gridPid }
        .compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { $0.width > 100 }
}
func windows() -> [AXUIElement] {
    var ref: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(textPid), kAXWindowsAttribute as CFString, &ref)
    return (ref as? [AXUIElement]) ?? []
}
func frame(_ w: AXUIElement) -> CGRect {
    var p: CFTypeRef?, s: CFTypeRef?
    AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &p); AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &s)
    var f = CGRect.zero; AXValueGetValue(p as! AXValue, .cgPoint, &f.origin); AXValueGetValue(s as! AXValue, .cgSize, &f.size); return f
}
func setFrame(_ w: AXUIElement, _ r: CGRect) {
    var pos = r.origin, size = r.size
    AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}
func focus(_ w: AXUIElement) { AXUIElementPerformAction(w, kAXRaiseAction as CFString); AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue); usleep(300_000) }
NSRunningApplication(processIdentifier: textPid)!.activate(); usleep(400_000)
let ws = windows(); guard ws.count >= 2 else { print("need 2 TextEdit windows, have", ws.count); exit(1) }
let a = ws[0], b = ws[1]
// A on display 2 (x < 0), B on display 1
setFrame(a, CGRect(x: -1500, y: 200, width: 700, height: 500)); setFrame(b, CGRect(x: 300, y: 200, width: 700, height: 500)); usleep(300_000)
print("A start", frame(a), " B start", frame(b))

print("== preset: Full screen (⌃⌥F) on A, expected to fill display 2")
focus(a); CGWarpMouseCursorPosition(CGPoint(x: 960, y: 900)); usleep(200_000)   // cursor on display 1 must not matter for presets
chord(CGKeyCode(kVK_ANSI_F), ctrlOpt); usleep(700_000)
let aFull = frame(a); print("A after preset", aFull, aFull.minX <= -1900 && aFull.width >= 1900 ? "OK" : "WRONG")

print("== undo (⌃⌥Z): A back to its start frame")
chord(CGKeyCode(kVK_ANSI_Z), ctrlOpt); usleep(700_000)
let aUndo = frame(a); print("A after undo", aUndo, abs(aUndo.minX - -1500) < 2 && abs(aUndo.width - 700) < 2 ? "OK" : "WRONG")
chord(CGKeyCode(kVK_ANSI_Z), ctrlOpt); usleep(700_000)   // redo
print("A after redo", frame(a), frame(a).width >= 1900 ? "OK" : "WRONG")

print("== ghosts: B focused on display 1, grid open; display 2's panel should outline A (snapped) as a ghost")
focus(b); usleep(300_000)
chord(CGKeyCode(kVK_Space), shiftCmd); usleep(900_000)
let ps = panels(); print("panels", ps.count)
let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
var args = ["-x"]
for (i, p) in ps.enumerated() { args += ["-R", "\(Int(p.minX)),\(Int(p.minY)),\(Int(p.width)),\(Int(p.height))", "/tmp/griddemo/panel\(i).png"] }
// screencapture takes one -R; capture each separately
for (i, p) in ps.enumerated() {
    let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    t.arguments = ["-x", "-R", "\(Int(p.minX)),\(Int(p.minY)),\(Int(p.width)),\(Int(p.height))", "/tmp/griddemo/panel-\(p.minX < 0 ? "d2" : "d1").png"]
    try! t.run(); t.waitUntilExit(); print("captured panel", i, p, "exit", t.terminationStatus)
}
key(53, down: true, []); key(53, down: false, []); usleep(600_000)
print("panels after esc", panels().count)
print("done")
