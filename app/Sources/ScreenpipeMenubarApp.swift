import SwiftUI

// Menu-bar-only app (LSUIElement). A state-colored dot opens the popover; the popover opens
// the Preferences (Settings scene) and About windows.
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

        Settings {
            PreferencesView()
        }

        Window("About screenpipe-menubar", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
