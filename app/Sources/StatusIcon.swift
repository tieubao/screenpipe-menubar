import AppKit

// The menu bar mark: a "memory-ring" (a clock whose hour ring is 12 capture-dots, hands at ~10:10)
// = a timeline assembled from continuous screen snapshots, the app's identity. Per the design spec,
// the glyph shape is CONSTANT across states; state is encoded by glyph opacity (full when capturing,
// dimmed when not) plus one colored status dot bottom-right (the single colored element). Drawn
// programmatically so there is no asset catalog; the glyph uses the label color (resolved in the
// status item's drawing appearance) so it reads on light and dark menu bars.
enum StatusIcon {
    static func image(for state: CaptureState) -> NSImage {
        let size: CGFloat = 18
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            drawGlyph(state: state, canvas: size)
            drawStatusDot(state: state, canvas: size)
            return true
        }
        // Non-template: the status dot must keep its color (a template image is forced monochrome).
        // The glyph is drawn in labelColor, which resolves to the drawing appearance, so it adapts.
        img.isTemplate = false
        img.accessibilityDescription = state.accessibility
        return img
    }

    // The clock-from-capture-dots glyph, in the label color, at state opacity.
    private static func drawGlyph(state: CaptureState, canvas s: CGFloat) {
        let c = CGPoint(x: s / 2, y: s / 2)
        let inkAlpha: CGFloat = state.glyphDimmed ? 0.55 : 1.0
        NSColor.labelColor.withAlphaComponent(inkAlpha).set()

        // 12 hour-mark dots on a ring (the "continuous captures around the clock").
        let ringR = 0.40 * s
        let dotR = 0.5 * 0.072 * s
        for h in 0..<12 {
            let theta = CGFloat(h) * (.pi / 6)              // 0 = top, clockwise
            let p = CGPoint(x: c.x + ringR * sin(theta), y: c.y + ringR * cos(theta))
            NSBezierPath(ovalIn: NSRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2)).fill()
        }

        // Hands at ~10:10 (friendly, and clear of the ring dots).
        let handW = 0.055 * s
        func hand(angleDeg: CGFloat, length: CGFloat) {
            let t = angleDeg * .pi / 180
            let end = CGPoint(x: c.x + length * sin(t), y: c.y + length * cos(t))
            let path = NSBezierPath()
            path.lineWidth = handW
            path.lineCapStyle = .round
            path.move(to: c)
            path.line(to: end)
            path.stroke()
        }
        hand(angleDeg: 300, length: 0.22 * s)               // hour hand -> 10 o'clock
        hand(angleDeg: 60, length: 0.32 * s)                // minute hand -> 2 o'clock

        // center hub
        let hubR = 0.5 * 0.06 * s
        NSBezierPath(ovalIn: NSRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2)).fill()
    }

    // The one colored element: a 5pt status dot bottom-right, with a clear knockout halo so it stays
    // legible against the nearest ring dots. Absent for `unknown` (no verdict yet).
    private static func drawStatusDot(state: CaptureState, canvas s: CGFloat) {
        guard let color = state.statusDotColor else { return }
        let d = 0.5 * 0.30 * s                               // ~5pt diameter at s=18
        let center = CGPoint(x: s - d - 1.0, y: d + 1.0)     // bottom-right inset

        if let ctx = NSGraphicsContext.current?.cgContext {
            let halo = d + 1.0                               // knockout a clear gap under the dot
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2))
            ctx.setBlendMode(.normal)
        }
        color.set()
        NSBezierPath(ovalIn: NSRect(x: center.x - d, y: center.y - d, width: d * 2, height: d * 2)).fill()
    }
}
