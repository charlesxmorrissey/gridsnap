import AppKit
import Carbon
// Scripted demo for the recording: TextEdit on display 1, grid opens on both, a drag on display 2's panel moves it
// there, then the grid opens again and a drag on display 1's panel brings it back to the right half.
let gridPid = pid_t(CommandLine.arguments[1])!, textPid = pid_t(CommandLine.arguments[2])!
func key(_ k: CGKeyCode, down: Bool, _ flags: CGEventFlags) {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = flags; e.post(tap: .cghidEventTap); usleep(40_000)
}
func hotkey() {   // ⇧⌘Space pressed the way a person does, modifiers down first and released last, so no flag lingers
    key(CGKeyCode(kVK_Shift), down: true, .maskShift); key(CGKeyCode(kVK_Command), down: true, [.maskShift, .maskCommand])
    key(CGKeyCode(kVK_Space), down: true, [.maskShift, .maskCommand]); key(CGKeyCode(kVK_Space), down: false, [.maskShift, .maskCommand])
    key(CGKeyCode(kVK_Command), down: false, .maskShift); key(CGKeyCode(kVK_Shift), down: false, [])
}
func mouse(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!; e.flags = []; e.post(tap: .cghidEventTap)
}
func glide(to p: CGPoint, steps: Int = 25) {   // move the cursor visibly rather than jumping
    let from = NSEvent.mouseLocation, top = NSScreen.screens[0].frame.maxY, start = CGPoint(x: from.x, y: top - from.y)
    for i in 1...steps { mouse(.mouseMoved, CGPoint(x: start.x + (p.x - start.x) * CGFloat(i) / CGFloat(steps), y: start.y + (p.y - start.y) * CGFloat(i) / CGFloat(steps))); usleep(16_000) }
}
func drag(_ p: CGPoint, to: CGPoint) {
    glide(to: p); usleep(250_000)
    mouse(.leftMouseDown, p)
    for i in 1...30 { usleep(30_000); mouse(.leftMouseDragged, CGPoint(x: p.x + (to.x - p.x) * CGFloat(i) / 30, y: p.y + (to.y - p.y) * CGFloat(i) / 30)) }
    usleep(300_000)
    mouse(.leftMouseUp, to)
}
func panels() -> [CGRect] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.filter { $0[kCGWindowOwnerPID as String] as? pid_t == gridPid }
        .compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) }.filter { $0.width > 100 }
}
let pad: CGFloat = 20, header: CGFloat = 64   // room around the cells, app icon and name above them
func cellPoint(_ p: CGRect, _ col: CGFloat, _ row: CGFloat) -> CGPoint {   // 10x10 grid, padded, below the header, row 0 at the top
    CGPoint(x: p.minX + pad + (p.width - 2 * pad) / 10 * col, y: p.minY + pad + header + (p.height - 2 * pad - header) / 10 * row)
}
NSRunningApplication(processIdentifier: textPid)!.activate(); usleep(300_000)
glide(to: CGPoint(x: 960, y: 700)); usleep(1_200_000)
hotkey(); usleep(1_200_000)
guard let p2 = panels().first(where: { $0.minX < 0 }) else { print("no panel on display 2"); exit(1) }
drag(cellPoint(p2, 0.5, 0.5), to: cellPoint(p2, 4.5, 9.5)); usleep(1_500_000)   // left half of display 2
hotkey(); usleep(1_200_000)
guard let p1 = panels().first(where: { $0.minX >= 0 }) else { print("no panel on display 1"); exit(1) }
drag(cellPoint(p1, 5.5, 0.5), to: cellPoint(p1, 9.5, 9.5)); usleep(1_500_000)   // right half of display 1
print("done")
