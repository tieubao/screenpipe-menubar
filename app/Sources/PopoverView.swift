import SwiftUI

// The full popover (MenuBarExtra .window style). Leads with state, then a Privacy card and a
// Storage card, then a quiet footer. Plain language throughout; one accent color at a time.
struct PopoverView: View {
    @ObservedObject var monitor: HealthMonitor
    @Environment(\.openWindow) private var openWindow

    private let storageBudget: Int64 = 10 * 1024 * 1024 * 1024  // 10 GB soft reference for the bar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            systemCard
            privacyCard
            storageCard
            openEntry
            footer
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { monitor.refreshDetails() }
    }

    // MARK: state header (Control-Center style)

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color(nsColor: monitor.state.color))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(monitor.state.label)
                    .font(.headline)
                Text(monitor.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            inlineControls
        }
    }

    @ViewBuilder
    private var inlineControls: some View {
        if monitor.state == .fail {
            Button("Start") { monitor.start() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        } else {
            HStack(spacing: 6) {
                Button("Pause") { monitor.pause(minutes: 60) }
                Button("Stop") { monitor.stop() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: privacy card

    private var privacyCard: some View {
        Card(title: "Privacy") {
            Row(label: "Redaction", value: "On, on-device")
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(cleanLabel).font(.callout)
                    Text(cleanCaption)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                cleanControls
            }
        }
    }

    private var cleanLabel: String {
        if monitor.checking && monitor.leftoverCount == nil { return "Checking\u{2026}" }
        switch monitor.leftoverCount {
        case .none:        return "Not checked yet"
        case .some(0):     return "Nothing to clean"
        case .some(let n): return "\(n) item\(n == 1 ? "" : "s") to clean"
        }
    }

    private var cleanCaption: String {
        if let checked = monitor.lastChecked {
            return "Checked \(HealthMonitor.relativeAge(checked))"
        }
        return "Leftover secrets in the local index"
    }

    @ViewBuilder
    private var cleanControls: some View {
        if monitor.cleaning || monitor.checking {
            ProgressView().controlSize(.small)
        } else if (monitor.leftoverCount ?? 0) > 0 {
            Button("Clean") { monitor.clean() }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: CaptureState.attention.color))
                .controlSize(.small)
        } else {
            Button("Check") { monitor.checkLeftovers() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    // MARK: system card (readiness + capture stats + integration)

    private var systemCard: some View {
        Card(title: "System") {
            HStack {
                Circle()
                    .fill(Color(nsColor: monitor.doctor.allPassed ? CaptureState.ok.color
                                                                   : CaptureState.attention.color))
                    .frame(width: 8, height: 8)
                Text(monitor.doctor.summary).font(.callout)
                Spacer()
                Button("Check") { monitor.refreshDetails() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            if !monitor.doctor.allPassed && !monitor.doctor.checks.isEmpty {
                ForEach(monitor.doctor.checks.filter { !$0.ok }) { c in
                    Text("\u{2022} \(c.name)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Divider()
            Row(label: "Frames captured", value: monitor.status.frames > 0
                ? "\(monitor.status.frames)" : "\u{2014}")
            Row(label: monitor.monitors.count == 1 ? "Display" : "Displays",
                value: monitor.monitors.isEmpty ? "\u{2014}" : monitor.monitors.joined(separator: ", "))
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude integration").font(.callout)
                    Text("Search your history from Claude (MCP)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Set up") { monitor.setupMCP() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    // MARK: storage card

    private var storageCard: some View {
        Card(title: "Storage") {
            ProgressView(value: storageFraction)
                .tint(.accentColor)
            HStack {
                Text(storageUsedText).font(.callout)
                Spacer()
                Text("Keeps \(monitor.retentionDays) days")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Row(label: "Last activity", value: monitor.lastActivity)
        }
    }

    private var storageFraction: Double {
        guard storageBudget > 0 else { return 0 }
        return min(1, Double(monitor.storageBytes) / Double(storageBudget))
    }

    private var storageUsedText: String {
        ByteCountFormatter.string(fromByteCount: monitor.storageBytes, countStyle: .file) + " used"
    }

    // MARK: open the main window

    // The headline entry: opens the real client window (Search/Timeline/Chat/Status/Settings).
    // NSApp.activate brings the accessory app forward so the window is focused on open.
    private var openEntry: some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        } label: {
            Label("Open screenpipe", systemImage: "rectangle.stack")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Settings\u{2026}") { openSettings() }
            Button("About") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.link)
        .font(.caption)
    }

    // Open the Settings scene from an accessory (menu-bar) app. The selector was renamed
    // across macOS versions, so try the current one then fall back.
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let current = Selector(("showSettingsWindow:"))
        let legacy = Selector(("showPreferencesWindow:"))
        if NSApp.responds(to: current) {
            NSApp.sendAction(current, to: nil, from: nil)
        } else {
            NSApp.sendAction(legacy, to: nil, from: nil)
        }
    }
}

// MARK: - reusable pieces

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Row: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            Text(value).font(.callout).foregroundStyle(.secondary)
        }
    }
}
