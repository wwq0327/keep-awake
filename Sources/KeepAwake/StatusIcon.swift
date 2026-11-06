import AppKit

/// Approved circular variant: a solid status-colored disc with a white
/// power ring and lightning bolt, on an 18 pt grid.
/// Use shape as well as color to distinguish the keep-awake switch:
/// - orange = keeping awake
/// - green  = running & user active
/// - gray   = not keeping (system may sleep)
enum StatusIcon {

    static func image(for state: DisplayState) -> NSImage {
        let color: NSColor
        switch state {
        case .keepingAwake: color = .systemOrange
        case .active:       color = .systemGreen
        case .idle:         color = .systemGray
        }

        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            color.set()
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 18, height: 18)).fill()

            // Match the approved preview: the white mark occupies 79% of
            // the disc, leaving an even margin around its original grid.
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let transform = NSAffineTransform()
            transform.translateX(by: 1.89, yBy: 1.89)
            transform.scale(by: 0.79)
            transform.concat()
            NSColor.white.set()
            let ring = NSBezierPath()
            ring.appendArc(
                withCenter: NSPoint(x: 9, y: 9), radius: 7,
                startAngle: -60, endAngle: 240
            )
            ring.lineWidth = 1.55
            ring.lineCapStyle = .round
            ring.stroke()

            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 10, y: 3.5))
            bolt.line(to: NSPoint(x: 5.6, y: 9.4))
            bolt.line(to: NSPoint(x: 8.6, y: 9.4))
            bolt.line(to: NSPoint(x: 7.9, y: 14.3))
            bolt.line(to: NSPoint(x: 12.4, y: 8))
            bolt.line(to: NSPoint(x: 9.4, y: 8))
            bolt.close()
            if state == .keepingAwake {
                bolt.fill()
            } else {
                bolt.lineWidth = 1.1
                bolt.lineJoinStyle = .round
                bolt.stroke()
            }
            return true
        }
        image.isTemplate = false // keep the actual color in the menu bar
        return image
    }
}
