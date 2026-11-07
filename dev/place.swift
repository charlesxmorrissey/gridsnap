import AppKit
let pid = pid_t(CommandLine.arguments[1])!
var ref: CFTypeRef?
AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &ref)
let win = ref as! AXUIElement
var pos = CGPoint(x: 660, y: 340), size = CGSize(width: 900, height: 560)
AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
