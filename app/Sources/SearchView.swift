import SwiftUI

// Search over screen history via the local screenpipe /search API. Debounced input, a content
// type toggle (All/Screen/Audio), a clean result list (time + source app + matched snippet), and
// designed idle/loading/empty/error states. Each row can jump to that moment in the Timeline.

struct SearchView: View {
    @EnvironmentObject private var router: ClientRouter

    @State private var query = ""
    @State private var contentType: SearchContentType = .all
    @State private var hits: [SearchHit] = []
    @State private var phase: Phase = .idle
    @State private var searchTask: Task<Void, Never>?

    enum Phase: Equatable {
        case idle, loading, empty
        case loaded
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
        }
        .navigationTitle("Search")
        .onChange(of: query) { _ in scheduleSearch() }
        .onChange(of: contentType) { _ in scheduleSearch() }
    }

    // MARK: controls

    private var controls: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search everything you've seen and heard", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
            if phase == .loading { ProgressView().controlSize(.small) }
            Picker("", selection: $contentType) {
                ForEach(SearchContentType.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(14)
    }

    // MARK: content (the four designed states)

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            placeholder(icon: "magnifyingglass",
                        title: "Search your history",
                        note: "Find anything you've seen on screen or heard. Type to begin.")
        case .loading:
            placeholder(icon: "hourglass", title: "Searching\u{2026}", note: "")
        case .empty:
            placeholder(icon: "tray",
                        title: "No matches",
                        note: "Nothing in your history matches \u{201C}\(query)\u{201D} yet.")
        case .error(let message):
            placeholder(icon: "exclamationmark.triangle",
                        title: "Search is unavailable",
                        note: message, tint: .orange)
        case .loaded:
            List(hits) { hit in ResultRow(hit: hit) { jump(to: hit) } }
                .listStyle(.inset)
        }
    }

    private func placeholder(icon: String, title: String, note: String,
                             tint: Color = .secondary) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(tint)
            Text(title).font(.title3.weight(.semibold))
            if !note.isEmpty {
                Text(note).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: search lifecycle (debounced)

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { phase = .idle; hits = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)   // debounce: no request per keystroke
            if Task.isCancelled { return }
            await runSearch(q)
        }
    }

    @MainActor
    private func runSearch(_ q: String) async {
        phase = .loading
        let cfg = ConfigStore.read()
        let port = Int(cfg["SCREENPIPE_PORT"] ?? "") ?? 3030
        let token = cfg["SCREENPIPE_API_TOKEN"]
        do {
            let results = try await SearchClient.search(port: port, token: token,
                                                        query: q, contentType: contentType)
            if Task.isCancelled { return }
            hits = results
            phase = results.isEmpty ? .empty : .loaded
        } catch {
            if Task.isCancelled { return }
            phase = .error(error.localizedDescription)
        }
    }

    private func jump(to hit: SearchHit) {
        router.jumpToTimeline(date: hit.timestamp, frameId: hit.frameId)
    }
}

// MARK: - result row

private struct ResultRow: View {
    let hit: SearchHit
    let onJump: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(hit.timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.caption.weight(.medium))
                    if let app = hit.appName, !app.isEmpty {
                        Text("\u{2022} \(app)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(hit.kind == "Audio" ? "Audio" : "Screen")
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Text(hit.text.isEmpty ? "(no text)" : hit.text)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(hit.text.isEmpty ? .secondary : .primary)
            }
            Spacer()
            Button(action: onJump) {
                Label("Jump", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
