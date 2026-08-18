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

    // MARK: menu bar icon state encoding (per the icon design spec)

    // The glyph dims when the app is NOT actively capturing (a second, color-independent channel).
    var glyphDimmed: Bool {
        switch self {
        case .ok, .attention: return false
        case .fail, .unknown: return true
        }
    }

    // The single colored element on the icon: a status dot. nil = no verdict yet (unknown).
    var statusDotColor: NSColor? {
        switch self {
        case .ok:        return .systemGreen
        case .attention: return .systemYellow
        case .fail:      return .systemRed
        case .unknown:   return nil
        }
    }

    // VoiceOver: lead with the app name, state the consequence, never color alone.
    var accessibility: String {
        switch self {
        case .ok:        return "screenpipe: recording your screen history"
        case .attention: return "screenpipe: capture paused, not recording"
        case .fail:      return "screenpipe: stopped, screen history is not being captured"
        case .unknown:   return "screenpipe: checking capture status"
        }
    }
}
