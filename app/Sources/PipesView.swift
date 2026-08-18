import SwiftUI
import AppKit

// Pipes = scheduled agents over screen data. Lists installed pipes (name, schedule, enabled) and
// enable/disable/run/install through the `screenpipe pipe` CLI, reflecting each action back. A
// one-line untrusted-pipe caution sits on Install (a third-party pipe runs code over your data).

struct PipesView: View {
    @State private var pipes: [PipeInfo] = []
    @State private var phase: Phase = .loading
    @State private var busy: Set<String> = []
    @State private var installURL = ""
    @State private var showInstallURL = false

    enum Phase: Equatable { case loading, empty, loaded; case error(String) }

    private var bin: String { Backend.screenpipeBin }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .navigationTitle("Pipes")
        .task { await reload() }
        .sheet(isPresented: $showInstallURL) { installSheet }
    }

    // MARK: header + install

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Scheduled agents that run over your screen history.")
                        .font(.callout)
                }
                Spacer()
                Menu {
                    Button("Install from folder\u{2026}") { installFromFolder() }
                    Button("Install from URL\u{2026}") { showInstallURL = true }
                } label: { Label("Install", systemImage: "plus") }
                    .menuStyle(.borderlessButton).fixedSize()
                Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }
            Label("A pipe runs code over your screen data. Only install pipes you trust.",
                  systemImage: "exclamationmark.shield")
                .font(.caption).foregroundStyle(.orange)
        }
        .padding(14)
    }

    private var installSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install a pipe from a URL").font(.headline)
            Text("A pipe runs code over your screen data. Only install from sources you trust.")
                .font(.caption).foregroundStyle(.orange)
            TextField("https://\u{2026} or a git URL", text: $installURL)
                .textFieldStyle(.roundedBorder).frame(width: 360)
            HStack {
                Spacer()
                Button("Cancel") { showInstallURL = false; installURL = "" }
                Button("Install") { let s = installURL; showInstallURL = false; installURL = ""
                    Task { await runInstall(s) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(installURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            placeholder(icon: "gearshape.2", title: "Loading pipes\u{2026}", note: "")
        case .empty:
            placeholder(icon: "gearshape.2",
                        title: "No pipes installed",
                        note: "Install one from a folder or URL. The public pipe store is currently empty.")
        case .error(let message):
            placeholder(icon: "exclamationmark.triangle", title: "Pipes unavailable", note: message, tint: .orange)
        case .loaded:
            List(pipes) { pipe in PipeRow(pipe: pipe, busy: busy.contains(pipe.name),
                                          onToggle: { await toggle(pipe) },
                                          onRun: { await runOnce(pipe) }) }
                .listStyle(.inset)
        }
    }

    private func placeholder(icon: String, title: String, note: String, tint: Color = .secondary) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(tint)
            Text(title).font(.title3.weight(.semibold))
            if !note.isEmpty { Text(note).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    // MARK: actions (each reflects back via reload)

    @MainActor private func reload() async {
        if phase != .loaded { phase = .loading }
        let b = bin
        do {
            let result = try await Task.detached { try PipesClient.list(bin: b) }.value
            pipes = result.sorted { $0.title < $1.title }
            phase = result.isEmpty ? .empty : .loaded
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    @MainActor private func toggle(_ pipe: PipeInfo) async {
        busy.insert(pipe.name)
        let b = bin, verb = pipe.enabled ? "disable" : "enable", name = pipe.name
        _ = await Task.detached { PipesClient.action(bin: b, verb: verb, name: name) }.value
        busy.remove(pipe.name)
        await reload()
    }

    @MainActor private func runOnce(_ pipe: PipeInfo) async {
        busy.insert(pipe.name)
        let b = bin, name = pipe.name
        _ = await Task.detached { PipesClient.action(bin: b, verb: "run", name: name) }.value
        busy.remove(pipe.name)
        await reload()
    }

    @MainActor private func runInstall(_ source: String) async {
        let b = bin
        _ = await Task.detached { PipesClient.install(bin: b, source: source) }.value
        await reload()
    }

    private func installFromFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Install"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await runInstall(url.path) }
        }
    }
}

private struct PipeRow: View {
    let pipe: PipeInfo
    let busy: Bool
    let onToggle: () async -> Void
    let onRun: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pipe.title).font(.callout.weight(.medium))
                HStack(spacing: 6) {
                    Text(pipe.name).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    Text("\u{2022} \(pipe.schedule)").font(.caption2).foregroundStyle(.secondary)
                    if pipe.isRunning {
                        Text("running").font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.green.opacity(0.18), in: Capsule()).foregroundStyle(.green)
                    }
                }
            }
            Spacer()
            if busy { ProgressView().controlSize(.small) }
            Button { Task { await onRun() } } label: { Image(systemName: "play.circle") }
                .buttonStyle(.borderless).disabled(busy)
                .help("Run once now")
            Toggle("", isOn: .init(get: { pipe.enabled }, set: { _ in Task { await onToggle() } }))
                .labelsHidden().toggleStyle(.switch).disabled(busy)
        }
        .padding(.vertical, 4)
    }
}
