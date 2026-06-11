import SwiftUI

// Scrub captured screen frames by time. Loads OCR frames in a window from the local API, maps a
// scrubber position to a frame, and previews the frame image alongside its OCR text + source app.
// A jump from Search (ClientRouter.timelineTarget) loads around that moment and lands on it.

struct TimelineView: View {
    @EnvironmentObject private var router: ClientRouter

    @State private var frames: [SearchHit] = []
    @State private var index: Double = 0
    @State private var displayIndex: Int = 0          // debounced index that drives the image load
    @State private var phase: Phase = .idle
    @State private var debounceTask: Task<Void, Never>?

    enum Phase: Equatable { case idle, loading, empty, loaded; case error(String) }

    private var current: SearchHit? {
        guard frames.indices.contains(displayIndex) else { return frames.last ?? frames.first }
        return frames[displayIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            if phase == .loaded, !frames.isEmpty { Divider(); scrubberBar }
        }
        .navigationTitle("Timeline")
        .task { if phase == .idle { await loadWindow(around: Date(), span: 86_400) } }
        .onChange(of: router.timelineTarget) { target in
            guard let target else { return }
            Task { await handleJump(target) }
        }
        .onChange(of: index) { _ in scheduleDisplayUpdate() }
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            placeholder(icon: "clock.arrow.circlepath", title: "Loading your timeline\u{2026}", note: "")
        case .empty:
            placeholder(icon: "clock",
                        title: "Nothing captured in this window",
                        note: "Scrub to another time, or open Search to find a moment.")
        case .error(let message):
            placeholder(icon: "exclamationmark.triangle", title: "Timeline unavailable",
                        note: message, tint: .orange)
        case .loaded:
            preview
        }
    }

    private var preview: some View {
        HStack(spacing: 0) {
            framePane
            Divider()
            ocrPane.frame(width: 280)
        }
    }

    private var framePane: some View {
        VStack(spacing: 8) {
            if let frame = current, let id = frame.frameId {
                AsyncImage(url: SearchClient.frameImageURL(port: configuredPort(), frameId: id)) { img in
                    img.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4))
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder(icon: "photo", title: "No frame", note: "")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ocrPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let frame = current {
                Text(frame.timestamp, format: .dateTime.month().day().hour().minute().second())
                    .font(.headline)
                if let app = frame.appName, !app.isEmpty {
                    Label(app, systemImage: "app.dashed").font(.callout).foregroundStyle(.secondary)
                }
                if let win = frame.windowName, !win.isEmpty {
                    Text(win).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Divider()
                Text("On screen").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView { Text(frame.text.isEmpty ? "(no text recognized)" : frame.text)
                    .font(.callout).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading) }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: scrubber

    private var scrubberBar: some View {
        VStack(spacing: 4) {
            Slider(value: $index, in: 0...Double(max(0, frames.count - 1)), step: 1)
            HStack {
                Text(frames.first?.timestamp ?? Date(), format: .dateTime.hour().minute())
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let c = current {
                    Text(c.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption.weight(.medium))
                    if let app = c.appName, !app.isEmpty {
                        Text("\u{2022} \(app)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(frames.last?.timestamp ?? Date(), format: .dateTime.hour().minute())
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func placeholder(icon: String, title: String, note: String,
                             tint: Color = .secondary) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(tint)
            Text(title).font(.title3.weight(.semibold))
            if !note.isEmpty { Text(note).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    // MARK: loading + scrub debounce

    private func configuredPort() -> Int {
        Int(ConfigStore.read()["SCREENPIPE_PORT"] ?? "") ?? 3030
    }

    @MainActor
    private func loadWindow(around center: Date, span: TimeInterval) async {
        phase = .loading
        let cfg = ConfigStore.read()
        let port = Int(cfg["SCREENPIPE_PORT"] ?? "") ?? 3030
        let token = cfg["SCREENPIPE_API_TOKEN"]
        do {
            let result = try await SearchClient.framesInRange(
                port: port, token: token,
                start: center.addingTimeInterval(-span / 2),
                end: center.addingTimeInterval(span / 2))
            frames = result
            phase = result.isEmpty ? .empty : .loaded
            index = Double(max(0, result.count - 1))
            displayIndex = Int(index)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func handleJump(_ target: TimelineTarget) async {
        await loadWindow(around: target.date, span: 7_200)   // +/- 1h around the jumped moment
        guard !frames.isEmpty else { return }
        // Land on the frame closest to the requested time.
        let nearest = frames.enumerated().min { a, b in
            abs(a.element.timestamp.timeIntervalSince(target.date)) <
            abs(b.element.timestamp.timeIntervalSince(target.date))
        }
        if let nearest { index = Double(nearest.offset); displayIndex = nearest.offset }
        router.timelineTarget = nil   // consume the jump
    }

    // Debounce the image-driving index so fast scrubbing doesn't fire an image load per step.
    private func scheduleDisplayUpdate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }
            await MainActor.run { displayIndex = Int(index) }
        }
    }
}
