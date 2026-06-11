import SwiftUI

// Menu-bar-only app (LSUIElement). Slice-1 scaffold: a state-colored dot + a minimal menu
// that shells out to screenpipe-ctl. The rich popover is sub-goal 05.
@main
struct ScreenpipeMenubarApp: App {
    @StateObject private var monitor = HealthMonitor()

    var body: some Scene {
        MenuBarExtra {
            Text("screenpipe: \(monitor.state.label)")
            Text(monitor.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Start capture") { Backend.ctl("start") }
            Button("Stop capture")  { Backend.ctl("stop") }
            Button("Pause 1 hour")  { Backend.ctl("pause", "60") }

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(nsImage: StatusIcon.image(for: monitor.state))
        }
    }
}
