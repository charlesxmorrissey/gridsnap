import AppKit
// Render a label pill (white text on a translucent black rounded box) to a PNG for ffmpeg to overlay.
let text = CommandLine.arguments[1], out = CommandLine.arguments[2]
let font = NSFont.systemFont(ofSize: 22, weight: .medium)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white.withAlphaComponent(0.92)]
let size = (text as NSString).size(withAttributes: attrs)
let pad: CGFloat = 10, w = ceil(size.width + pad * 2), h = ceil(size.height + pad)
let img = NSImage(size: NSSize(width: w, height: h))
img.lockFocus()
NSColor.black.withAlphaComponent(0.55).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h), xRadius: 8, yRadius: 8).fill()
(text as NSString).draw(at: NSPoint(x: pad, y: pad / 2), withAttributes: attrs)
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print(out, Int(w), Int(h))
