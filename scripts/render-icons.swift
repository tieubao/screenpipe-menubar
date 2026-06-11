// Render the menu bar icon for each state to PNGs for visual review (not shipped).
//   swiftc app/Sources/StatusIcon.swift app/Sources/CaptureState.swift scripts/render-icons.swift \
//     -o /tmp/sp-icons && /tmp/sp-icons
import AppKit

@main
enum RenderIcons {
    static func main() {
        let states: [(String, CaptureState)] = [("ok", .ok), ("attention", .attention),
                                                 ("fail", .fail), ("unknown", .unknown)]
        let scale: CGFloat = 10
        let px = Int(18 * scale)
        for (name, st) in states {
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                             isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
            NSColor(white: 0.96, alpha: 1).setFill()         // light menu-bar-ish backdrop
            NSRect(x: 0, y: 0, width: 18, height: 18).fill()
            StatusIcon.image(for: st).draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            NSGraphicsContext.restoreGraphicsState()
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/icon-\(name).png"))
            }
        }
        print("wrote /tmp/icon-{ok,attention,fail,unknown}.png at \(Int(scale))x")
    }
}
