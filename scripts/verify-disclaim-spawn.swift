// Smoke test for the disclaiming spawn (the Screen Recording re-prompt fix):
//   swiftc app/Sources/DisclaimedSpawn.swift scripts/verify-disclaim-spawn.swift -o /tmp/sp-spawn \
//     && /tmp/sp-spawn
//
// Proves the posix_spawn + responsibility-disclaim path runs a tool and captures stdout + exit
// status correctly (so Backend.run still works after routing through it). The TCC no-prompt itself
// is observed live (Han clicks the menu bar app).

import Foundation

@main
enum VerifyDisclaim {
    static func main() {
        // captures stdout + success
        let echo = DisclaimedSpawn.run("/bin/echo", ["disclaim-ok"])
        guard echo.ok, echo.out.trimmingCharacters(in: .whitespacesAndNewlines) == "disclaim-ok" else {
            fail("echo via disclaimed spawn failed: \(echo)")
        }
        // non-zero exit is reported as not-ok
        let f = DisclaimedSpawn.run("/usr/bin/false", [])
        guard !f.ok else { fail("/usr/bin/false reported ok") }
        // zero exit reported ok
        let t = DisclaimedSpawn.run("/usr/bin/true", [])
        guard t.ok else { fail("/usr/bin/true reported not-ok") }
        // a missing binary is a clean failure, not a crash
        let missing = DisclaimedSpawn.run("/nope/not/here", [])
        guard !missing.ok else { fail("missing binary reported ok") }

        print("OK: disclaimed spawn captures stdout + exit status (echo, true, false, missing-bin)")
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
