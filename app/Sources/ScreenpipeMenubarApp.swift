import SwiftUI

// Menu-bar-only app (LSUIElement). A state-colored dot in the menu bar opens the full
// popover (PopoverView) in a window-style MenuBarExtra.
@main
struct ScreenpipeMenubarApp: App {
    @StateObject private var monitor = HealthMonitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            Image(nsImage: StatusIcon.image(for: monitor.state))
        }
        .menuBarExtraStyle(.window)
    }
}
