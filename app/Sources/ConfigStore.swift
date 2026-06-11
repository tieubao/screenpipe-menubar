import Foundation

// Reads/writes the shell-style ~/.config/screenpipe-menubar/config that the capture launcher
// sources. Preserves unknown lines; only the keys we manage are rewritten.
enum ConfigStore {
    static var path: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".config/screenpipe-menubar/config")
    }

    static func read() -> [String: String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        var out: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eq])
            let value = String(line[line.index(after: eq)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            out[key] = value
        }
        return out
    }

    // Merge updates into the existing file, preserving comments + unmanaged lines.
    static func write(_ updates: [String: String]) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var lines = (try? String(contentsOfFile: path, encoding: .utf8))?
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init) ?? []
        var remaining = updates
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eq])
            if let newValue = remaining[key] {
                lines[i] = "\(key)=\(quote(newValue))"
                remaining.removeValue(forKey: key)
            }
        }
        for (key, value) in remaining { lines.append("\(key)=\(quote(value))") }
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    // Quote values that contain spaces or are empty, so the shell sources them intact.
    private static func quote(_ value: String) -> String {
        if value.isEmpty || value.contains(" ") { return "\"\(value)\"" }
        return value
    }
}
