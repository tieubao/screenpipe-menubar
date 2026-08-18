import Foundation

// Read-only status values for the Status section, sourced from the real capture launcher + the
// MCP client configs (NOT hardcoded in Swift). Foundation-only so the parse can be checked
// headlessly (scripts/verify-status.swift).

struct RedactionInfo: Equatable {
    var backend: String          // --pii-backend (e.g. "local")
    var labels: [String]         // --pii-redaction-labels
    var textRedaction: Bool      // --use-pii-removal
    var imageRedaction: Bool     // --async-image-pii-redaction
    var extraPatternCount: Int   // bundled secret-pattern entries (scrub-elements coverage)
    var enabled: Bool { textRedaction || imageRedaction }
    var isLocal: Bool { backend.lowercased() == "local" }
}

struct MCPClient: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var configured: Bool         // the client's config references screenpipe
    var hasConfig: Bool          // the config file exists at all
    var detail: String
}

enum StatusInfo {
    // The installed capture launcher (the source of truth for the runtime pii flags), with the
    // bundled repo copy as a dev fallback.
    static func launcherPath() -> String {
        let installed = (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin/screenpipe-capture")
        return FileManager.default.fileExists(atPath: installed) ? installed : "bin/screenpipe-capture"
    }

    static func patternsPath() -> String? {
        let p = (NSHomeDirectory() as NSString).appendingPathComponent(".local/share/screenpipe-menubar/patterns/secrets.json")
        if FileManager.default.fileExists(atPath: p) { return p }
        return FileManager.default.fileExists(atPath: "patterns/secrets.json") ? "patterns/secrets.json" : nil
    }

    // Parse the launcher for the live redaction flags.
    static func redaction(launcherPath path: String, patternsPath patterns: String?) -> RedactionInfo {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let backend = token(in: text, after: "--pii-backend") ?? "local"
        let labelsCSV = token(in: text, after: "--pii-redaction-labels") ?? ""
        let labels = labelsCSV.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var patternCount = 0
        if let patterns, let data = FileManager.default.contents(atPath: patterns),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            patternCount = arr.count
        }
        return RedactionInfo(backend: backend, labels: labels,
                             textRedaction: text.contains("--use-pii-removal"),
                             imageRedaction: text.contains("--async-image-pii-redaction"),
                             extraPatternCount: patternCount)
    }

    // The token immediately after a CLI flag (space-separated, quote/backslash tolerant).
    static func token(in text: String, after flag: String) -> String? {
        guard let range = text.range(of: flag) else { return nil }
        let rest = text[range.upperBound...].drop { $0 == " " || $0 == "\t" }
        let token = rest.prefix { !$0.isWhitespace && $0 != "\\" }
        let t = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        return t.isEmpty ? nil : t
    }

    // Scan known MCP client config locations for a screenpipe reference (read-only detection).
    static func mcpClients(home: String) -> [MCPClient] {
        let candidates: [(String, String)] = [
            ("Claude Code", "\(home)/.claude.json"),
            ("Claude Desktop", "\(home)/Library/Application Support/Claude/claude_desktop_config.json"),
            ("Codex", "\(home)/.codex/config.toml"),
        ]
        return candidates.map { name, path in
            let exists = FileManager.default.fileExists(atPath: path)
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let configured = text.lowercased().contains("screenpipe")
            return MCPClient(name: name, configured: configured, hasConfig: exists,
                             detail: !exists ? "No config" : (configured ? "Connected" : "Not wired"))
        }
    }
}
