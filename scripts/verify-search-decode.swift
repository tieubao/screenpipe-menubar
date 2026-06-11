// Headless check for sub-goal 02: compile the Foundation-only SearchClient with this main and
// decode the /search fixture, proving the request/response mapping matches screenpipe's schema.
//
//   swiftc app/Sources/SearchClient.swift scripts/verify-search-decode.swift -o /tmp/sp-decode \
//     && /tmp/sp-decode fixtures/search-response.json
//
// Exits non-zero unless >=1 row decodes and the key fields (text, timestamp, app, kind) map.
// Wrapped in @main because top-level code is only allowed in main.swift when multiple files
// are compiled together.

import Foundation

@main
enum VerifySearchDecode {
    static func main() {
        let path = CommandLine.arguments.dropFirst().first ?? "fixtures/search-response.json"
        guard let data = FileManager.default.contents(atPath: path) else {
            fail("fixture not found: \(path)", code: 2)
        }
        do {
            let hits = try SearchClient.decode(data)
            guard !hits.isEmpty else { fail("decoded 0 rows") }

            // Request-shape check: the URL carries the documented params.
            let u = SearchClient.searchURL(base: SearchClient.baseURL(port: 3030),
                                           query: "revenue", contentType: .ocr, limit: 30).absoluteString
            for needle in ["/search?", "q=revenue", "content_type=ocr", "limit=30", "offset=0"] {
                guard u.contains(needle) else { fail("request URL missing \(needle): \(u)") }
            }

            // Field-mapping check on the first OCR row.
            let first = hits[0]
            guard !first.text.isEmpty, first.timestamp.timeIntervalSince1970 > 0,
                  first.appName == "Safari", first.kind == "OCR", first.frameId == 48213 else {
                fail("field mapping off: \(first)")
            }
            // Audio row maps transcription -> text.
            guard hits.contains(where: { $0.kind == "Audio" && $0.text.contains("push the launch") }) else {
                fail("audio transcription not mapped")
            }

            print("OK: decoded \(hits.count) rows; request shape + field mapping verified")
            print("  row0: [\(first.kind)] \(first.appName ?? "?") @ \(first.timestamp) - \(first.text.prefix(48))")
        } catch {
            fail("decode threw: \(error)")
        }
    }

    private static func fail(_ message: String, code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
