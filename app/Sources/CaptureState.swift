import AppKit

// The capture's health, mapped to the Apple system colors the menu bar dot uses
// (matching the screenpipe-ctl semantics): green ok, amber attention, red stopped.
enum CaptureState {
    case ok          // capturing
    case attention   // up but not producing frames (stale / starting)
    case fail        // API down / not running
    case unknown     // not yet polled

    var color: NSColor {
        switch self {
        case .ok:        return NSColor(srgbRed: 0x34/255.0, green: 0xC7/255.0, blue: 0x59/255.0, alpha: 1) // #34c759
        case .attention: return NSColor(srgbRed: 0xFF/255.0, green: 0x95/255.0, blue: 0x00/255.0, alpha: 1) // #ff9500
        case .fail:      return NSColor(srgbRed: 0xFF/255.0, green: 0x3B/255.0, blue: 0x30/255.0, alpha: 1) // #ff3b30
        case .unknown:   return NSColor(srgbRed: 0x8E/255.0, green: 0x8E/255.0, blue: 0x93/255.0, alpha: 1) // gray
        }
    }

    var label: String {
        switch self {
        case .ok:        return "Recording"
        case .attention: return "Not capturing"
        case .fail:      return "Stopped"
        case .unknown:   return "Checking\u{2026}"
        }
    }
}
