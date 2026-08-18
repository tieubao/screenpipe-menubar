// Headless check for sub-goal 04: the Status panels read REAL values (the capture launcher + MCP
// client configs), not hardcoded Swift constants.
//
//   swiftc app/Sources/StatusInfo.swift scripts/verify-status.swift -o /tmp/sp-status && /tmp/sp-status
//
// Positive: parsing bin/screenpipe-capture yields backend=local, the 10 pii labels, text+image
// redaction on, and >0 bundled patterns. Negative control: a launcher with no pii flags yields no
// labels + disabled (proves the values are parsed, not invented). MCP: detection flips with the
// config content.

import Foundation

@main
enum VerifyStatus {
    static func main() {
        // --- positive: real launcher ---
        let r = StatusInfo.redaction(launcherPath: "bin/screenpipe-capture",
                                     patternsPath: "patterns/secrets.json")
        guard r.backend.lowercased() == "local" else { fail("backend not local: \(r.backend)") }
        for label in ["secret", "person", "email", "phone", "credit_card", "iban", "us_ssn"] {
            guard r.labels.contains(label) else { fail("pii label '\(label)' not parsed: \(r.labels)") }
        }
        guard r.textRedaction, r.imageRedaction, r.enabled else { fail("redaction flags off: \(r)") }
        guard r.extraPatternCount > 0 else { fail("no bundled patterns counted") }

        // --- negative control: a launcher with no pii flags must yield nothing ---
        let fake = "/tmp/sp-fake-launcher"
        try? "#!/bin/sh\nscreenpipe add --port 3030\n".write(toFile: fake, atomically: true, encoding: .utf8)
        let n = StatusInfo.redaction(launcherPath: fake, patternsPath: nil)
        guard n.labels.isEmpty, !n.enabled else { fail("negative control leaked values: \(n)") }

        // --- MCP detection flips with content ---
        let home = "/tmp/sp-status-home"
        try? FileManager.default.createDirectory(atPath: "\(home)/.codex", withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: "\(home)/Library/Application Support/Claude",
                                                 withIntermediateDirectories: true)
        try? #"{ "mcpServers": { "screenpipe": { "command": "screenpipe" } } }"#
            .write(toFile: "\(home)/.claude.json", atomically: true, encoding: .utf8)
        try? "model = \"gpt\"\n".write(toFile: "\(home)/.codex/config.toml", atomically: true, encoding: .utf8)
        let clients = StatusInfo.mcpClients(home: home)
        guard let claude = clients.first(where: { $0.name == "Claude Code" }), claude.configured else {
            fail("Claude Code should be detected as configured")
        }
        guard let codex = clients.first(where: { $0.name == "Codex" }), !codex.configured, codex.hasConfig else {
            fail("Codex should be present-but-not-wired")
        }

        print("OK: redaction backend=\(r.backend), \(r.labels.count) labels, text+image on, "
              + "\(r.extraPatternCount) patterns; MCP detection flips (claude=on, codex=off)")
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
