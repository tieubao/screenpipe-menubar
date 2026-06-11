import SwiftUI

// Chat over your screen history. Each question retrieves relevant moments via the local /search
// API, grounds the model on them, and answers, local Ollama by default (no egress), cloud only
// when the 06 opt-in is on. A persistent privacy badge shows Local vs Cloud; answers cite the
// retrieved source moments, each able to jump to the Timeline.

struct ChatView: View {
    @EnvironmentObject private var router: ClientRouter

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var sending = false
    @State private var settings = LLMSettings.default

    struct ChatMessage: Identifiable {
        let id = UUID()
        enum Role { case user, assistant, system }
        let role: Role
        let text: String
        var sources: [SearchHit] = []
    }

    var body: some View {
        VStack(spacing: 0) {
            privacyBadge
            Divider()
            transcript
            Divider()
            composer
        }
        .navigationTitle("Chat")
        .onAppear { settings = LLMSettings.load() }
    }

    // MARK: privacy badge (always visible)

    private var privacyBadge: some View {
        let plan = ChatEngine.plan(settings)
        return HStack(spacing: 6) {
            Image(systemName: plan.willEgress ? "cloud" : "lock.fill")
            Text(plan.badge).font(.caption.weight(.medium))
            if !plan.willEgress {
                Text("nothing leaves your Mac").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("history excerpts are sent to the cloud").font(.caption2).foregroundStyle(.orange)
            }
            Spacer()
        }
        .foregroundStyle(plan.willEgress ? Color.orange : Color.green)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
                            Text("Ask about anything you've seen or heard").font(.title3.weight(.semibold))
                            Text("Grounded in your local history. Local model by default.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                    ForEach(messages) { msg in MessageView(message: msg) { jump(to: $0) }.id(msg.id) }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    // MARK: composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask your history\u{2026}", text: $input, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...4)
                .onSubmit { send() }
            if sending { ProgressView().controlSize(.small) }
            Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .buttonStyle(.borderless)
                .disabled(sending || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(14)
    }

    private func jump(to hit: SearchHit) { router.jumpToTimeline(date: hit.timestamp, frameId: hit.frameId) }

    // MARK: send

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !sending else { return }
        settings = LLMSettings.load()                       // re-read provider/opt-in fresh each send
        messages.append(ChatMessage(role: .user, text: question))
        input = ""
        sending = true
        Task { await answer(question) }
    }

    @MainActor
    private func answer(_ question: String) async {
        defer { sending = false }
        let cfg = ConfigStore.read()
        let port = Int(cfg["SCREENPIPE_PORT"] ?? "") ?? 3030
        let token = cfg["SCREENPIPE_API_TOKEN"]
        // 1. retrieve grounding moments from the LOCAL /search API
        var context: [SearchHit] = []
        do { context = try await SearchClient.search(port: port, token: token, query: question,
                                                     contentType: .all, limit: 12) } catch { context = [] }
        // 2. the cloud key is fetched from Keychain ONLY when the user opted in
        let apiKey = settings.willEgress
            ? KeychainStore.get(account: settings.provider.keychainAccount) : nil
        // 3. ask the model (loopback unless opted in; ask() hard-blocks un-opted-in egress)
        do {
            let reply = try await ChatEngine.ask(question: question, settings: settings,
                                                 apiKey: apiKey, context: context)
            messages.append(ChatMessage(role: .assistant, text: reply, sources: context))
        } catch {
            messages.append(ChatMessage(role: .system, text: error.localizedDescription))
        }
    }
}

private struct MessageView: View {
    let message: ChatView.ChatMessage
    let onJump: (SearchHit) -> Void

    var body: some View {
        switch message.role {
        case .user:
            HStack { Spacer()
                Text(message.text).padding(10)
                    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 460, alignment: .trailing)
            }
        case .system:
            Label(message.text, systemImage: "exclamationmark.triangle")
                .font(.callout).foregroundStyle(.orange)
        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text).textSelection(.enabled)
                    .frame(maxWidth: 540, alignment: .leading)
                if !message.sources.isEmpty {
                    Text("Sources").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(message.sources.prefix(5)) { src in
                        Button { onJump(src) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(src.timestamp, format: .dateTime.month().day().hour().minute())
                                if let app = src.appName, !app.isEmpty {
                                    Text("\u{2022} \(app)").foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain).foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
