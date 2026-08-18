// LIVE end-to-end check: hit the running screenpipe /search API through SearchClient.
//   TOKEN=$(screenpipe auth token)
//   swiftc app/Sources/SearchClient.swift scripts/verify-search-live.swift -o /tmp/sp-live \
//     && /tmp/sp-live "$TOKEN"            # expect rows
//      /tmp/sp-live                       # no token -> the auth error (negative control)
//
// Proves the auth fix: Search works against the real auth-enabled API only when a token is passed.

import Foundation

@main
enum VerifySearchLive {
    static func main() async {
        let token = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
        do {
            let hits = try await SearchClient.search(port: 3030, token: token, query: "",
                                                     contentType: .ocr, limit: 5)
            guard !hits.isEmpty else {
                FileHandle.standardError.write(Data("LIVE: 0 rows (capture empty or query too narrow)\n".utf8))
                exit(1)
            }
            // the frame-image URL carries the token as a query param (AsyncImage can't set a header)
            let furl = SearchClient.frameImageURL(port: 3030, frameId: hits[0].frameId ?? 0, token: token)
            print("LIVE OK: \(hits.count) rows; row0 app=\(hits[0].appName ?? "?") frame=\(hits[0].frameId.map(String.init) ?? "?")")
            print("  frame image URL: \(furl.absoluteString)")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("LIVE: \(error.localizedDescription)\n".utf8))
            exit(1)   // expected when no token is passed (the negative control)
        }
    }
}
