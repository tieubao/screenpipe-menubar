import Foundation

// Thin bridge to the slice-1 shell backend. ALL capture/redaction logic stays in the
// portable scripts; the app only shells out and reads results. The one user-facing concept
// here is "clean": the privacy tool that removes leftover secrets from the local index.
enum Backend {
    static var binDir: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin")
    }
    static var ctlPath: String { (binDir as NSString).appendingPathComponent("screenpipe-ctl") }
    // The privacy-cleaner script. Referenced by path only; never shown to the user verbatim.
    static var cleanerPath: String { (binDir as NSString).appendingPathComponent("scrub-elements.py") }

    static var dataDir: String {
        if let dir = readConfig("SCREENPIPE_DATA_DIR") { return (dir as NSString).expandingTildeInPath }
        return (NSHomeDirectory() as NSString).appendingPathComponent(".screenpipe")
    }

    // The screenpipe CLI itself (direct Rust binary, else PATH), for status/doctor/mcp.
    static var screenpipeBin: String {
        let direct = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".cache/.bun/install/global/node_modules/@screenpipe/cli-darwin-arm64/bin/screenpipe")
        if FileManager.default.isExecutableFile(atPath: direct) { return direct }
        for p in ["\(NSHomeDirectory())/.cache/.bun/bin/screenpipe", "/opt/homebrew/bin/screenpipe"] {
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return direct
    }

    static func statusReport() -> StatusReport { ReportParser.status(run(url(screenpipeBin), ["status"]).out) }
    static func doctorReport() -> DoctorReport { ReportParser.doctor(run(url(screenpipeBin), ["doctor"]).out) }
    @discardableResult
    static func mcpSetup() -> Bool { run(url(screenpipeBin), ["mcp", "setup"]).ok }

    // Safe, arg-free maintenance: flush the WAL into the main DB file. No data is deleted.
    @discardableResult
    static func optimizeDatabase() -> Bool { run(url(screenpipeBin), ["backup", "checkpoint"]).ok }

    private static func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    @discardableResult
    static func ctl(_ args: String...) -> Bool {
        run(URL(fileURLWithPath: ctlPath), args).ok
    }

    // Count leftover secrets in the local index (the "Check" action). Parses the cleaner's
    // dry-run line: "scanned N rows, M contain residual secret(s)". Returns M, or nil on error.
    static func itemsToCleanCount() -> Int? {
        let r = run(URL(fileURLWithPath: "/usr/bin/python3"), [cleanerPath, "--dry-run"])
        guard r.ok else { return nil }
        // pull the second integer from the summary line
        let nums = r.out.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return nums.count >= 2 ? nums[1] : (nums.first ?? nil)
    }

    // Run the cleaner for real (the "Clean" action), then return the new leftover count.
    @discardableResult
    static func clean() -> Int? {
        _ = run(URL(fileURLWithPath: "/usr/bin/python3"), [cleanerPath])
        return itemsToCleanCount()
    }

    static func dataSizeBytes() -> Int64 {
        let r = run(URL(fileURLWithPath: "/usr/bin/du"), ["-sk", dataDir])
        guard r.ok, let kb = r.out.split(whereSeparator: { !$0.isNumber }).first.flatMap({ Int64($0) })
        else { return 0 }
        return kb * 1024
    }

    static func retentionDays() -> Int {
        Int(readConfig("SCREENPIPE_RETENTION_DAYS") ?? "") ?? 14
    }

    // MARK: - helpers

    // Spawn local tools with TCC responsibility DISCLAIMED (DisclaimedSpawn) so a spawned tool
    // runs under its own TCC identity, not the GUI app's. This is what stops the Screen Recording
    // re-prompt: `screenpipe doctor` probes screen recording, and without disclaiming, the app
    // (un-granted) is the responsible process and macOS re-prompts on every popover open. All
    // callees here are absolute-path local tools, so disclaiming is safe + correct for all of them.
    private static func run(_ url: URL, _ args: [String]) -> (ok: Bool, out: String) {
        DisclaimedSpawn.run(url.path, args)
    }

    private static func readConfig(_ key: String) -> String? {
        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".config/screenpipe-menubar/config")
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("\(key)=") else { continue }
            return line.dropFirst(key.count + 1)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        }
        return nil
    }
}
