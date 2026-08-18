// Headless check for sub-goal 05: parse `screenpipe pipe list --json` + the action argv shapes.
//
//   swiftc app/Sources/PipesClient.swift scripts/verify-pipes.swift -o /tmp/sp-pipes \
//     && /tmp/sp-pipes fixtures/pipe-list.json [<screenpipe-bin>]
//
// Decodes the sanitized fixture (real schema from a live `pipe list --json`) to rows with
// name/enabled/schedule/title, checks the enable/disable/run/install argv shapes, and runs a
// negative control. If a screenpipe binary path is passed, it ALSO parses the LIVE list.

import Foundation

@main
enum VerifyPipes {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let path = args.first ?? "fixtures/pipe-list.json"
        guard let data = FileManager.default.contents(atPath: path) else { fail("fixture not found: \(path)", 2) }

        do {
            let pipes = try PipesClient.decode(data)
            guard !pipes.isEmpty else { fail("decoded 0 pipes") }
            guard let first = pipes.first(where: { !$0.name.isEmpty }) else { fail("pipe has no name") }
            guard !first.schedule.isEmpty, !first.title.isEmpty else { fail("pipe missing schedule/title: \(first)") }
            // at least one enabled pipe with a real schedule maps through
            guard pipes.contains(where: { $0.enabled }) else { fail("no enabled pipe decoded") }

            // argv shapes (no mutation executed)
            guard PipesClient.listArgs() == ["pipe", "list", "--json"] else { fail("list argv off") }
            guard PipesClient.actionArgs("enable", name: "x") == ["pipe", "enable", "x"] else { fail("enable argv off") }
            guard PipesClient.actionArgs("disable", name: "x") == ["pipe", "disable", "x"] else { fail("disable argv off") }
            guard PipesClient.actionArgs("run", name: "x") == ["pipe", "run", "x"] else { fail("run argv off") }
            guard PipesClient.installArgs("/tmp/p") == ["pipe", "install", "/tmp/p"] else { fail("install argv off") }

            // negative control: malformed JSON must throw
            var threw = false
            do { _ = try PipesClient.decode(Data("not json".utf8)) } catch { threw = true }
            guard threw else { fail("negative control: malformed JSON did not throw") }

            var liveNote = "(no live bin)"
            if args.count > 1, FileManager.default.isExecutableFile(atPath: args[1]) {
                let live = try PipesClient.list(bin: args[1])
                guard !live.isEmpty else { fail("live list returned 0 pipes") }
                liveNote = "live=\(live.count) pipes"
            }

            print("OK: \(pipes.count) pipes decoded (\(pipes.filter{$0.enabled}.count) enabled); argv shapes ok; \(liveNote)")
            print("  pipe0: \(first.title) [\(first.name)] schedule=\(first.schedule) enabled=\(first.enabled)")
        } catch {
            fail("decode threw: \(error)")
        }
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
