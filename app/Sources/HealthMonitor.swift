import Foundation
import Combine

// Polls the local screenpipe /health endpoint on a timer and derives the menu bar state.
// Reads the API port from the slice-1 config if present, else screenpipe's default 3030.
@MainActor
final class HealthMonitor: ObservableObject {
    @Published private(set) var state: CaptureState = .unknown
    @Published private(set) var detail: String = "checking\u{2026}"

    private let port: Int
    private var timer: Timer?

    init() {
        port = HealthMonitor.configuredPort()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

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
                    self.state = .fail
                    self.detail = "not running"
                    return
                }
                let frame = (json["frame_status"] as? String) ?? "unknown"
                let message = (json["message"] as? String) ?? ""
                self.apply(frame: frame, message: message)
            }
        }.resume()
    }

    private func apply(frame: String, message: String) {
        switch frame {
        case "ok":
            state = .ok; detail = "capturing"
        case "stale":
            state = .attention; detail = "frames stale"
        case "not_started":
            state = .attention; detail = "starting\u{2026}"
        default:
            if message.lowercased().contains("healthy") && !message.lowercased().contains("not healthy") {
                state = .ok; detail = "healthy"
            } else {
                state = .attention; detail = message.isEmpty ? frame : message
            }
        }
    }

    // Parse SCREENPIPE_PORT from ~/.config/screenpipe-menubar/config (shell-style), else 3030.
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
