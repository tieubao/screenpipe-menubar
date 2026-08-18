import Foundation
import Darwin

// Spawn a local tool with TCC responsibility DISCLAIMED so the child is its own responsible
// process and ITS OWN TCC grants apply, not the GUI app's. This is the fix for the Screen
// Recording re-prompt: the menu bar app spawns the screenpipe CLI (which probes screen recording
// in `doctor`); without disclaiming, macOS attributes the check to the app (un-granted) and
// re-prompts every time. With disclaim, the already-granted `screenpipe` binary's grant is used.
//
// `responsibility_spawnattrs_setdisclaim` is a libSystem symbol with no public header; it is
// stable and widely used (Homebrew, tmux, etc.). Declared via @_silgen_name.

@_silgen_name("responsibility_spawnattrs_setdisclaim")
private func responsibility_spawnattrs_setdisclaim(
    _ attrs: UnsafeMutablePointer<posix_spawnattr_t?>, _ disclaim: Int32) -> Int32

enum DisclaimedSpawn {
    // Runs `path args`, returns (success, stdout). stderr is discarded (matches the old Process path).
    static func run(_ path: String, _ args: [String]) -> (ok: Bool, out: String) {
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        _ = responsibility_spawnattrs_setdisclaim(&attr, 1)   // <- the fix

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }

        var fds: [Int32] = [-1, -1]
        guard pipe(&fds) == 0 else { return (false, "") }     // fds[0] read, fds[1] write
        posix_spawn_file_actions_adddup2(&actions, fds[1], 1)                 // stdout -> pipe
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0) // stderr -> /dev/null
        posix_spawn_file_actions_addclose(&actions, fds[0])
        posix_spawn_file_actions_addclose(&actions, fds[1])

        var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) }
        argv.append(nil)
        defer { for p in argv where p != nil { free(p) } }

        var pid: pid_t = 0
        let rc = posix_spawn(&pid, path, &actions, &attr, argv, environ)
        close(fds[1])                                          // parent doesn't write
        guard rc == 0 else { close(fds[0]); return (false, "") }

        var data = Data()
        let cap = 8192
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: cap)
        defer { buf.deallocate() }
        while true {
            let n = read(fds[0], buf, cap)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        close(fds[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let exited = (status & 0x7f) == 0
        let code = (status >> 8) & 0xff
        return (exited && code == 0, String(decoding: data, as: UTF8.self))
    }
}
