import AppKit
// A plain dark backdrop over the wallpaper and the desktop widgets of display 1, under every app window, for recordings.
// Runs until killed: `swiftc -O dev/backdrop.swift -o build/backdrop && build/backdrop &`.
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
final class G: NSView { override func draw(_ r: NSRect) { NSGradient(colors: [NSColor(red: 0.16, green: 0.22, blue: 0.34, alpha: 1), NSColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 1)])!.draw(in: bounds, angle: -60) } }
let s = NSScreen.screens[0]
let w = NSWindow(contentRect: s.frame, styleMask: .borderless, backing: .buffered, defer: false)
w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 10)   // desktop widgets (Notification Center) sit at +2
w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]; w.ignoresMouseEvents = true
w.contentView = G(); w.setFrame(s.frame, display: true); w.orderFront(nil)
app.run()
