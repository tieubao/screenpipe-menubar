import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @State private var retention = "14"
    @State private var languages = "english"
    @State private var excludes = ""
    @State private var port = "3030"
    @State private var openAtLogin = false
    @State private var note = ""

    var body: some View {
        Form {
            Section("Capture") {
                TextField("Retention (days)", text: $retention)
                TextField("OCR languages", text: $languages)
                    .help("Space-separated, e.g. \"english vietnamese\"")
                TextField("Also exclude windows", text: $excludes)
                    .help("Space-separated window/app matchers, beyond the built-in defaults")
                TextField("API port", text: $port)
            }

            Section("App") {
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { setOpenAtLogin($0) }
            }

            Section("Maintenance") {
                Button("Optimize database now") { Backend.optimizeDatabase() }
                Button("Open data folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: Backend.dataDir))
                }
            }

            Section {
                HStack {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                    if !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 430)
        .onAppear(perform: load)
    }

    private func load() {
        let cfg = ConfigStore.read()
        retention = cfg["SCREENPIPE_RETENTION_DAYS"] ?? "14"
        languages = cfg["SCREENPIPE_LANGUAGES"] ?? "english"
        excludes  = cfg["SCREENPIPE_EXTRA_IGNORED_WINDOWS"] ?? ""
        port      = cfg["SCREENPIPE_PORT"] ?? "3030"
        if #available(macOS 13.0, *) {
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func save() {
        ConfigStore.write([
            "SCREENPIPE_RETENTION_DAYS": retention,
            "SCREENPIPE_LANGUAGES": languages,
            "SCREENPIPE_EXTRA_IGNORED_WINDOWS": excludes,
            "SCREENPIPE_PORT": port,
        ])
        note = "Saved. Restart capture to apply."
    }

    private func setOpenAtLogin(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            note = "Could not change login item: \(error.localizedDescription)"
        }
    }
}
