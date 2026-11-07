import Cocoa

func cellRange(_ lo: CGFloat, _ hi: CGFloat, _ n: Int) -> ClosedRange<Int> {
    let a = Int((lo * CGFloat(n)).rounded()), b = Int((hi * CGFloat(n)).rounded()) - 1
    let c = min(max(Int((lo + hi) / 2 * CGFloat(n)), 0), n - 1)
    return a <= b ? max(a, 0)...min(b, n - 1) : c...c
}

// One grid panel per display while the grid is open, index matching NSScreen.screens. Only one panel holds a
// selection at a time; the window snaps to that panel's display, so a drag on another display moves it there.
var grids: [GridView] = []
var gridActive = false
var original: (CGPoint, CGSize)?   // target window frame when the grid opened, restored on cancel
var moved = false
var selected: GridView? { grids.first { $0.selection != nil } }

func preview() {   // live: the window follows the selection and snaps back when there is none
    guard let win = targetWindow else { return }
    if let r = selected?.selectionFrame { applyFrame(win, r); moved = true } else if moved, let o = original { axSet(win, o.0, o.1) }
}
func commitGrid(save: Bool) {
    guard gridActive else { return }
    gridActive = false
    preview()
    if selected != nil, let w = targetWindow { remember(w); if let o = original { lastSnap = (w, o.0, o.1) } }
    let f = (save || recordMode) ? selected?.selectionFraction : nil   // shift saves a preset
    hideGrid()
    if let f { newPreset(f) }
}
func cancelGrid() {
    guard gridActive else { return }
    gridActive = false
    grids.forEach { $0.clear() }
    preview(); hideGrid()
}

final class GridView: NSView {
    var screen: NSScreen = .main!
    lazy var panel = makePanel(self)
    var start: (Int, Int)?, end: (Int, Int)?, pending = false
    var hover: (Int, Int)?   // the cell under the cursor lights up, like Divvy
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }

    static let pad: CGFloat = 28, headerHeight: CGFloat = 96   // Divvy's proportions: room around the cells, a tall header
    var header: CGFloat { targetApp == nil ? 0 : GridView.headerHeight }   // icon and name of the target app; 0 when there is no target
    var grid: NSRect { NSRect(x: GridView.pad, y: GridView.pad, width: bounds.width - 2 * GridView.pad, height: bounds.height - 2 * GridView.pad - header) }
    func cell(_ e: NSEvent) -> (Int, Int) {
        let p = convert(e.locationInWindow, from: nil)
        return (min(max(Int((p.x - grid.minX) / grid.width * CGFloat(cols)), 0), cols - 1),
                min(max(Int((p.y - grid.minY) / grid.height * CGFloat(rows)), 0), rows - 1))
    }
    var selection: (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
        guard let s = start, let e = end else { return nil }
        return (min(s.0, e.0)...max(s.0, e.0), min(s.1, e.1)...max(s.1, e.1))
    }
    var selectionFraction: NSRect? {
        guard let s = selection else { return nil }
        return NSRect(x: Double(s.x.lowerBound) / Double(cols), y: Double(s.y.lowerBound) / Double(rows),
                      width: Double(s.x.count) / Double(cols), height: Double(s.y.count) / Double(rows))
    }
    var selectionFrame: NSRect? { selectionFraction.map { screenFrame(fraction: $0, on: screen) } }

    var ghosts: [NSRect] = []
    func clear() { start = nil; end = nil; pending = false; hover = nil; needsDisplay = true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseMoved(with e: NSEvent) {
        let c = grid.contains(convert(e.locationInWindow, from: nil)) ? cell(e) : nil
        if c?.0 != hover?.0 || c?.1 != hover?.1 { hover = c; needsDisplay = true }
    }
    override func mouseEntered(with e: NSEvent) { mouseMoved(with: e) }
    override func mouseExited(with e: NSEvent) { if hover != nil { hover = nil; needsDisplay = true } }
    func claim() { for g in grids where g !== self { g.clear() } }   // a selection here drops any on another display

    override func mouseDown(with e: NSEvent) {
        guard gridActive else { return }
        claim(); start = cell(e); end = start; pending = false; needsDisplay = true   // no preview yet: one cell is a tiny window, wait for the drag
    }
    func track(_ e: NSEvent) {   // the drag clamps to the edge cell outside the panel, like Divvy; Esc is the way out
        guard gridActive else { return }
        let new = cell(e)
        guard new.0 != end?.0 || new.1 != end?.1 else { return }   // only hit AX when the cell changes
        end = new; needsDisplay = true; preview()
    }
    override func mouseDragged(with e: NSEvent) { track(e) }
    override func mouseUp(with e: NSEvent) { track(e); commitGrid(save: e.modifierFlags.contains(.shift)) }
    override func keyDown(with e: NSEvent) {
        guard gridActive else { return }
        if e.keyCode == 53 { cancelGrid(); return }   // esc, also mid-drag
        let shift = e.modifierFlags.contains(.shift)
        switch e.specialKey {
        case .carriageReturn?, .enter?: commitGrid(save: shift)
        case .tab?: focus(1)
        case .backTab?: focus(-1)
        case .leftArrow?: step(-1, 0, resize: shift)
        case .rightArrow?: step(1, 0, resize: shift)
        case .downArrow?: step(0, -1, resize: shift)
        case .upArrow?: step(0, 1, resize: shift)
        default: break
        }
    }
    func focus(_ by: Int) {   // tab moves the keyboard to the next display's grid
        guard let i = grids.firstIndex(where: { $0 === self }) else { return }
        let g = grids[(i + by + grids.count) % grids.count]
        g.panel.makeKey(); g.panel.makeFirstResponder(g)
    }
    func step(_ dx: Int, _ dy: Int, resize: Bool) {
        var lo = (0, 0), hi = (cols - 1, rows - 1)   // no selection on this display yet: start from the whole of it
        if let s = selection {
            lo = (s.x.lowerBound, s.y.lowerBound); hi = (s.x.upperBound, s.y.upperBound)
            if resize {
                hi = (min(max(hi.0 + dx, lo.0), cols - 1), min(max(hi.1 + dy, lo.1), rows - 1))
            } else {
                let mx = min(max(dx, -lo.0), cols - 1 - hi.0), my = min(max(dy, -lo.1), rows - 1 - hi.1)
                lo = (lo.0 + mx, lo.1 + my); hi = (hi.0 + mx, hi.1 + my)
            }
            if !pending, lo == (s.x.lowerBound, s.y.lowerBound), hi == (s.x.upperBound, s.y.upperBound) { return }
        }
        claim(); start = lo; end = hi; pending = false; needsDisplay = true; preview()
    }

    override func draw(_ dirty: NSRect) {
        guard !grid.isEmpty else { return }   // layer-backed views get drawn at zero size before the panel is shown
        if let app = targetApp {   // header: the app the window belongs to, same on every display
            let icon = NSRect(x: grid.minX, y: grid.maxY + (header - 48) / 2, width: 48, height: 48)
            app.icon?.draw(in: icon, from: .zero, operation: .sourceOver, fraction: 1)
            let name = NSAttributedString(string: app.localizedName ?? "", attributes: [
                .font: NSFont.systemFont(ofSize: 26, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.92)])
            let s = name.size()
            name.draw(in: NSRect(x: icon.maxX + 16, y: icon.midY - s.height / 2, width: grid.maxX - icon.maxX - 16, height: s.height))
        }
        let cw = grid.width / CGFloat(cols), ch = grid.height / CGFloat(rows)
        func edge(_ c: CGFloat, _ size: CGFloat, _ tol: CGFloat, _ sign: CGFloat) -> CGFloat {   // 5pt gap at every cell boundary
            let i = c.rounded()
            return abs(c - i) <= tol ? i * size + sign * 2.5 : c * size
        }
        func path(_ r: NSRect, tolX: CGFloat = 0, tolY: CGFloat = 0) -> NSBezierPath {
            let x0 = grid.minX + edge(r.minX, cw, tolX, 1), x1 = grid.minX + edge(r.maxX, cw, tolX, -1)
            let y0 = grid.minY + edge(r.minY, ch, tolY, 1), y1 = grid.minY + edge(r.maxY, ch, tolY, -1)
            return NSBezierPath(roundedRect: NSRect(x: x0, y: y0, width: max(x1 - x0, 0), height: max(y1 - y0, 0)), xRadius: 4, yRadius: 4)
        }
        func rect(_ x: ClosedRange<Int>, _ y: ClosedRange<Int>) -> NSBezierPath {
            path(NSRect(x: x.lowerBound, y: y.lowerBound, width: x.count, height: y.count))
        }
        for x in 0..<cols { for y in 0..<rows {
            let p = rect(x...x, y...y)
            NSColor(white: 0.24, alpha: 1).setFill(); p.fill()
            NSColor(white: 1, alpha: 0.16).setStroke(); p.stroke()
        }}
        let v = screen.visibleFrame, c = CGFloat(cols), r = CGFloat(rows)
        for u in ghosts {   // other snapped windows, faint
            let p = path(NSRect(x: u.minX * c, y: u.minY * r, width: u.width * c, height: u.height * r), tolX: 2 * c / v.width, tolY: 2 * r / v.height)
            NSColor(white: 1, alpha: 0.10).setFill(); p.fill()
        }
        if let s = selection {
            let p = rect(s.x, s.y)
            if pending {   // the cells the window covers now: an outline only, the keyboard starts from it
                NSColor(white: 1, alpha: 0.45).setStroke(); p.lineWidth = 1; p.stroke()
            } else {
                NSColor(white: 0.62, alpha: 1).setFill(); p.fill()
                NSColor(white: 1, alpha: 0.5).setStroke(); p.lineWidth = 1; p.stroke()
            }
        }
        if let h = hover, start == nil || pending {   // under the cursor, until a drag starts
            let p = rect(h.0...h.0, h.1...h.1)
            NSColor(white: 0.62, alpha: 1).setFill(); p.fill()
        }
    }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func resignKey() {   // the keyboard moving to another grid panel (Tab, a click on it) keeps the grid; anywhere else dismisses
        super.resignKey()
        DispatchQueue.main.async { if !(NSApp.keyWindow is Panel) { cancelGrid() } }
    }
}

func makePanel(_ view: GridView) -> Panel {
    let panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let back = NSView()   // solid dark gray like Divvy; nothing behind the panel shows through
    back.wantsLayer = true
    back.layer?.backgroundColor = NSColor(white: 0.40, alpha: 1).cgColor
    back.layer?.borderColor = NSColor(white: 1, alpha: 0.7).cgColor
    back.layer?.borderWidth = 1
    back.layer?.cornerRadius = 18; back.layer?.masksToBounds = true
    back.addSubview(view)
    panel.contentView = back
    panel.appearance = NSAppearance(named: .darkAqua)
    panel.hasShadow = true   // the opaque rounded backdrop gives the shadow its shape
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
    return panel
}

func showGrid() {
    targetWindow = recordMode ? nil : pickTarget()   // before the panels appear; record mode moves nothing
    original = targetWindow.flatMap(axFrame)
    if original == nil { targetWindow = nil }
    targetApp = targetWindow.flatMap(appOf)
    moved = false
    let screens = NSScreen.screens, ghosts = ghostFrames()
    while grids.count < screens.count { grids.append(GridView()) }
    while grids.count > screens.count { grids.removeLast().panel.orderOut(nil) }
    let home = targetWindow.map(screenOf) ?? screenUnderCursor()   // this display's grid outlines the window and takes the keyboard
    var key = grids[0]
    for (g, s) in zip(grids, screens) {
        g.screen = s; g.clear()
        g.ghosts = ghosts.map { screenFraction(of: $0, on: s) }.filter { !$0.isEmpty }
        if s.frame == home.frame { key = g }
        if let o = original, s.frame == home.frame {
            let r = NSRect(x: o.0.x, y: NSScreen.screens[0].frame.maxY - o.0.y - o.1.height, width: o.1.width, height: o.1.height)
            let u = screenFraction(of: r, on: s)
            if !u.isEmpty {
                let x = cellRange(u.minX, u.maxX, cols), y = cellRange(u.minY, u.maxY, rows)
                g.start = (x.lowerBound, y.lowerBound); g.end = (x.upperBound, y.upperBound); g.pending = true
            }
        }
        let f = s.visibleFrame, w: CGFloat = 480, p = GridView.pad, h = (w - 2 * p) * f.height / f.width + 2 * p + g.header   // the cells keep the display's aspect; padding and header add to it
        g.panel.setFrame(NSRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h), display: true)
        g.frame = g.panel.contentView!.bounds
        g.panel.alphaValue = 0
        g.panel.orderFront(nil)
    }
    gridActive = true
    key.panel.makeKeyAndOrderFront(nil)
    key.panel.makeFirstResponder(key)
    NSAnimationContext.runAnimationGroup { c in c.duration = 0.12; grids.forEach { $0.panel.animator().alphaValue = 1 } }
}
func hideGrid() {
    recordMode = false
    NSAnimationContext.runAnimationGroup({ c in c.duration = 0.10; grids.forEach { $0.panel.animator().alphaValue = 0 } }) {
        if !gridActive { grids.forEach { $0.panel.orderOut(nil) } }
    }
}
