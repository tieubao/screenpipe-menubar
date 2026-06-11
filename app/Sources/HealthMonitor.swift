import Foundation
import Combine

// Polls the local screenpipe /health endpoint and surfaces the values the popover shows:
// capture state, last activity, storage used, and how many leftover secrets remain.
@MainActor
final class HealthMonitor: ObservableObject {
    @Published private(set) var state: CaptureState = .unknown
    @Published private(set) var detail: String = "checking\u{2026}"
    @Published private(set) var lastActivity: String = "\u{2014}"

    @Published private(set) var storageBytes: Int64 = 0
    @Published private(set) var retentionDays: Int = 14

    // nil = checking; otherwise the number of leftover secrets the cleaner would remove.
    @Published private(set) var leftoverCount: Int? = nil
    @Published private(set) var cleaning = false

    private let port: Int
    private var timer: Timer?
    private let work = DispatchQueue(label: "app.screenpipe.menubar.backend", qos: .utility)

    init() {
        port = HealthMonitor.configuredPort()
        retentionDays = Backend.retentionDays()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // Live health (cheap, every 5s).
    func refresh() {
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let data,
                      let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.state = .fail; self.detail = "not running"; self.lastActivity = "\u{2014}"
                    return
                }
                let frame = (json["frame_status"] as? String) ?? "unknown"
                let message = (json["message"] as? String) ?? ""
                self.applyState(frame: frame, message: message)
                self.lastActivity = Self.relativeTime(json["last_frame_timestamp"] as? String)
            }
        }.resume()
    }

    // Heavier reads (storage + leftover count), run on popover open and after a clean.
    func refreshDetails() {
        work.async { [weak self] in
            let size = Backend.dataSizeBytes()
            let days = Backend.retentionDays()
            let count = Backend.itemsToCleanCount()
            Task { @MainActor in
                guard let self else { return }
                self.storageBytes = size
                self.retentionDays = days
                self.leftoverCount = count
            }
        }
    }

    // The "Clean" action: remove leftover secrets, then re-check.
    func clean() {
        cleaning = true
        work.async { [weak self] in
            let count = Backend.clean()
            Task { @MainActor in
                guard let self else { return }
                self.leftoverCount = count
                self.cleaning = false
            }
        }
    }

    func start() { Backend.ctl("start"); refresh() }
    func stop()  { Backend.ctl("stop"); refresh() }
    func pause(minutes: Int) { Backend.ctl("pause", String(minutes)); refresh() }

    // MARK: - derivations

    private func applyState(frame: String, message: String) {
        switch frame {
        case "ok":
            state = .ok; detail = "Capturing your screen"
        case "stale":
            state = .attention; detail = "Up, but no recent frames"
        case "not_started":
            state = .attention; detail = "Starting\u{2026}"
        default:
            if message.lowercased().contains("healthy") && !message.lowercased().contains("not healthy") {
                state = .ok; detail = "Capturing your screen"
            } else {
                state = .attention; detail = "Attention needed"
            }
        }
    }

    static func relativeTime(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "\u{2014}" }
        let secs = max(0, Int(Date().timeIntervalSince(date)))
        switch secs {
        case 0..<60:     return "just now"
        case 60..<3600:  return "\(secs / 60) min ago"
        case 3600..<86400: return "\(secs / 3600) hr ago"
        default:         return "\(secs / 86400) d ago"
        }
    }

    static func configuredPort() -> Int {
        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".config/screenpipe-menubar/config")
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return 3030 }
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("SCREENPIPE_PORT=") else { continue }
            let value = line.dropFirst("SCREENPIPE_PORT=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if let p = Int(value) { return p }
        }
        return 3030
    }
}
