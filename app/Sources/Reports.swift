import Foundation

// Parsed reports from the screenpipe CLI, for the status + readiness sections.

struct StatusReport {
    var running: Bool = false
    var frames: Int = 0
    var dataSizeText: String = "\u{2014}"
    var monitors: [String] = []
}

struct DoctorReport {
    struct Check: Identifiable {
        let id = UUID()
        let name: String
        let ok: Bool
    }
    var checks: [Check] = []
    var allPassed: Bool { !checks.isEmpty && checks.allSatisfy { $0.ok } }
    var summary: String {
        if checks.isEmpty { return "Not checked" }
        let failed = checks.filter { !$0.ok }
        return failed.isEmpty ? "Ready to record" : "\(failed.count) issue\(failed.count == 1 ? "" : "s")"
    }
}

enum ReportParser {
    // `screenpipe status` -> frames + data size + monitors (running line handled via /health).
    static func status(_ raw: String) -> StatusReport {
        var r = StatusReport()
        for line in raw.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.lowercased().hasPrefix("frames:") {
                r.frames = Int(l.split(whereSeparator: { !$0.isNumber }).first ?? "") ?? 0
            } else if l.lowercased().hasPrefix("data size:") {
                r.dataSizeText = l.replacingOccurrences(of: "data size:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return r
    }

    // `screenpipe doctor` -> the indented "name: ok|<other>" lines under permissions/deps/services.
    static func doctor(_ raw: String) -> DoctorReport {
        var r = DoctorReport()
        for line in raw.split(separator: "\n") {
            let l = String(line)
            // indented "  name: value" lines only (skip section headers + the summary line)
            guard l.hasPrefix("  "), let colon = l.firstIndex(of: ":") else { continue }
            let name = l[l.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            let value = l[l.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { continue }
            r.checks.append(.init(name: name, ok: value.lowercased() == "ok" || value.lowercased() == "available"))
        }
        return r
    }
}
