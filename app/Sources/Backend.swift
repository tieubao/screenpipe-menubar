import Foundation

// Thin bridge to the slice-1 shell backend. ALL capture logic stays in the portable
// scripts; the app only shells out. Resolves screenpipe-ctl at its installed location.
enum Backend {
    static var ctlPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin/screenpipe-ctl")
    }

    @discardableResult
    static func ctl(_ args: String...) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ctlPath)
        proc.arguments = args
        do {
            try proc.run()
            return true
        } catch {
            NSLog("screenpipe-ctl \(args.joined(separator: " ")) failed: \(error.localizedDescription)")
            return false
        }
    }
}
