import SwiftUI

// Shared navigation state for the main window. Lets one surface route to another, e.g. Search's
// jump-to-frame selects the Timeline section and hands it the moment to scrub to. Held as a
// @StateObject in the App and injected into the main window via .environmentObject.

struct TimelineTarget: Equatable {
    let date: Date
    let frameId: Int?
}

final class ClientRouter: ObservableObject {
    @Published var section: ClientSection = .search
    // Set by Search's jump-to-frame; read (and cleared) by the Timeline surface.
    @Published var timelineTarget: TimelineTarget?

    func jumpToTimeline(date: Date, frameId: Int?) {
        timelineTarget = TimelineTarget(date: date, frameId: frameId)
        section = .timeline
    }
}
