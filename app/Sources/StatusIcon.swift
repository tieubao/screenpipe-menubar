import AppKit

// Renders the menu bar dot as a NON-template (colored) SF Symbol so the state color shows
// in the menu bar. Template images would be forced monochrome by the system.
enum StatusIcon {
    static func image(for state: CaptureState) -> NSImage {
        let base = NSImage(systemSymbolName: "circle.fill",
                           accessibilityDescription: "screenpipe capture status")
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [state.color]))
        let img = base?.withSymbolConfiguration(cfg) ?? NSImage()
        img.isTemplate = false
        return img
    }
}
