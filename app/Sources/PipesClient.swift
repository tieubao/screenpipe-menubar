import Foundation

// Client for the `screenpipe pipe` CLI (scheduled agents over screen data). Foundation-only and
// dependency-free (takes the binary path as a param) so the parse can be checked headlessly. The
// JSON shape is `screenpipe pipe list --json`: an array of { config{name,enabled,schedule,title,
// description}, is_running, last_run }.

struct PipeInfo: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var enabled: Bool
    var schedule: String
    var title: String
    var description: String?
    var isRunning: Bool
    var lastRun: String?
}

enum PipeError: Error, LocalizedError {
    case decode(String)
    case cli(String)
    var errorDescription: String? {
        switch self {
        case .decode(let m): return "Could not read the pipe list: \(m)"
        case .cli(let m):    return m.isEmpty ? "The screenpipe CLI failed." : m
        }
    }
}

enum PipesClient {
    // argv builders (pure) so the command shapes are verifiable without executing mutations.
    static func listArgs() -> [String] { ["pipe", "list", "--json"] }
    static func actionArgs(_ verb: String, name: String) -> [String] { ["pipe", verb, name] }   // enable|disable|run
    static func installArgs(_ source: String) -> [String] { ["pipe", "install", source] }

    // Decode `pipe list --json`. Pure + public for the fixture/live check.
    static func decode(_ data: Data) throws -> [PipeInfo] {
        do {
            let rows = try JSONDecoder().decode([Row].self, from: data)
            return rows.map { r in
                PipeInfo(name: r.config.name,
                         enabled: r.config.enabled ?? false,
                         schedule: r.config.schedule ?? "manual",
                         title: r.config.title ?? prettify(r.config.name),
                         description: r.config.description,
                         isRunning: r.is_running ?? false,
                         lastRun: r.last_run)
            }
        } catch {
            throw PipeError.decode(String(describing: error))
        }
    }

    // MARK: live (shell out to the resolved screenpipe binary)

    static func list(bin: String) throws -> [PipeInfo] {
        let (ok, data) = run(bin, listArgs())
        guard ok else { throw PipeError.cli(String(decoding: data, as: UTF8.self)) }
        return try decode(data)
    }

    @discardableResult
    static func action(bin: String, verb: String, name: String) -> Bool {
        run(bin, actionArgs(verb, name: name)).ok
    }

    @discardableResult
    static func install(bin: String, source: String) -> Bool {
        run(bin, installArgs(source)).ok
    }

    private static func run(_ bin: String, _ args: [String]) -> (ok: Bool, out: Data) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return (proc.terminationStatus == 0, data)
        } catch {
            return (false, Data())
        }
    }

    private static func prettify(_ name: String) -> String {
        name.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    private struct Row: Decodable {
        let config: Config
        let is_running: Bool?
        let last_run: String?
        struct Config: Decodable {
            let name: String
            let enabled: Bool?
            let schedule: String?
            let title: String?
            let description: String?
        }
    }
}
