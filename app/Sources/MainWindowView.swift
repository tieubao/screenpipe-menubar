import SwiftUI

// The main app window: a NavigationSplitView shell the deep surfaces (Search, Timeline, Chat,
// Status, Settings) hang on. Opened on demand from the menu bar popover; the app stays a menu
// bar accessory (LSUIElement) and shows this real window only when asked, so there is no Dock
// icon churn. Each section is a stub here; later sub-goals grow them in place.

enum ClientSection: String, CaseIterable, Identifiable {
    case search, timeline, chat, status, pipes, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:   return "Search"
        case .timeline: return "Timeline"
        case .chat:     return "Chat"
        case .status:   return "Status"
        case .pipes:    return "Pipes"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .search:   return "magnifyingglass"
        case .timeline: return "clock"
        case .chat:     return "bubble.left.and.bubble.right"
        case .status:   return "checkmark.shield"
        case .pipes:    return "puzzlepiece"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var router: ClientRouter

    // List wants a Binding<ClientSection?>; the router holds a non-optional section so other
    // surfaces can route without unwrapping. Bridge the two here.
    private var selection: Binding<ClientSection?> {
        Binding(get: { router.section }, set: { if let s = $0 { router.section = s } })
    }

    var body: some View {
        NavigationSplitView {
            List(ClientSection.allCases, selection: selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .navigationTitle("screenpipe")
        } detail: {
            detail(for: router.section)
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    // The routing enum -> detail view. Kept as one switch so the wiring is greppable and every
    // ClientSection case is exhaustively handled (the compiler enforces coverage).
    @ViewBuilder
    private func detail(for section: ClientSection) -> some View {
        switch section {
        case .search:   SearchView()
        case .timeline: TimelineView()
        case .chat:     ChatSurface()
        case .status:   StatusView()
        case .pipes:    PipesView()
        case .settings: SettingsLLMView()
        }
    }
}

// MARK: - stub surfaces (each grown by its own sub-goal)

private struct SurfaceStub: View {
    let title: String
    let systemImage: String
    let note: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            Text(note).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}

struct ChatSurface: View {
    var body: some View {
        SurfaceStub(title: "Chat", systemImage: "bubble.left.and.bubble.right",
                    note: "Ask questions over your history. Local by default.")
    }
}

