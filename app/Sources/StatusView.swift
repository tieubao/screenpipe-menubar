import SwiftUI

// Two read-only status panels: Redaction/PII (what is protecting you) and MCP (integration +
// connected clients). Values come from the real capture launcher + client configs via StatusInfo,
// not hardcoded. Both render from config files, so they are unaffected by capture being paused.

struct StatusView: View {
    @State private var redaction = RedactionInfo(backend: "local", labels: [], textRedaction: false,
                                                 imageRedaction: false, extraPatternCount: 0)
    @State private var clients: [MCPClient] = []
    @State private var mcpBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                redactionPanel
                mcpPanel
                Text("Panels read your saved configuration, so they stay accurate while capture is paused.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("Status")
        .task { load() }
    }

    private func load() {
        redaction = StatusInfo.redaction(launcherPath: StatusInfo.launcherPath(),
                                         patternsPath: StatusInfo.patternsPath())
        clients = StatusInfo.mcpClients(home: NSHomeDirectory())
    }

    // MARK: redaction panel

    private var redactionPanel: some View {
        Panel(title: "Redaction / PII", systemImage: "lock.shield") {
            HStack {
                Label(redaction.isLocal ? "Local, on-device" : redaction.backend,
                      systemImage: redaction.isLocal ? "desktopcomputer" : "cloud")
                    .font(.callout.weight(.medium))
                Spacer()
                StatusPill(on: redaction.enabled, onText: "On", offText: "Off")
            }
            Divider()
            row("Text redaction", on: redaction.textRedaction)
            row("Image redaction", on: redaction.imageRedaction)
            Text("On-device models, post-capture and async: a text NER model redacts recognized "
                 + "entities, an image model blurs them in frames.")
                .font(.caption).foregroundStyle(.secondary)

            if !redaction.labels.isEmpty {
                Divider()
                Text("Redacted entities").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(redaction.labels, id: \.self) { Chip(text: $0) }
                }
            }
            if redaction.extraPatternCount > 0 {
                Row(label: "Bundled secret patterns", value: "\(redaction.extraPatternCount)")
            }
            Divider()
            Label("Local redaction reduces leaks; it is not a guarantee. Treat the index as sensitive.",
                  systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private func row(_ label: String, on: Bool) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            StatusPill(on: on, onText: "On", offText: "Off")
        }
    }

    // MARK: mcp panel

    private var mcpPanel: some View {
        Panel(title: "Claude / MCP integration", systemImage: "point.3.connected.trianglepath.dotted") {
            Text("Search your history from AI tools over screenpipe's MCP server.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(clients) { client in
                HStack {
                    Image(systemName: client.configured ? "checkmark.circle.fill"
                                                         : (client.hasConfig ? "circle" : "minus.circle"))
                        .foregroundStyle(client.configured ? Color.green : .secondary)
                    Text(client.name).font(.callout)
                    Spacer()
                    Text(client.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                if mcpBusy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Set up MCP") { setupMCP() }
                    .buttonStyle(.bordered).disabled(mcpBusy)
            }
        }
    }

    private func setupMCP() {
        mcpBusy = true
        Task {
            _ = await Task.detached { Backend.mcpSetup() }.value
            await MainActor.run { clients = StatusInfo.mcpClients(home: NSHomeDirectory()); mcpBusy = false }
        }
    }
}

// MARK: - small reusable pieces

private struct Panel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage).font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

private struct StatusPill: View {
    let on: Bool
    let onText: String
    let offText: String
    var body: some View {
        Text(on ? onText : offText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background((on ? Color.green : Color.secondary).opacity(0.18), in: Capsule())
            .foregroundStyle(on ? Color.green : .secondary)
    }
}

private struct Row: View {
    let label: String
    let value: String
    var body: some View {
        HStack { Text(label).font(.callout); Spacer(); Text(value).font(.callout).foregroundStyle(.secondary) }
    }
}
