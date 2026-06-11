import Foundation

// Client for screenpipe's local HTTP API `GET /search`. Foundation-only (no SwiftUI) so the
// decode path can be compiled + exercised headlessly against a fixture (see
// scripts/verify-search-decode.swift). Reads OCR + audio-transcript + UI text by content type.
//
// screenpipe /search response shape (documented + stable):
//   { "data": [ { "type": "OCR",   "content": { "text": "...", "timestamp": "...Z",
//                                                "app_name": "...", "window_name": "...",
//                                                "frame_id": 123, "file_path": "...",
//                                                "offset_index": 0 } },
//               { "type": "Audio", "content": { "transcription": "...", "timestamp": "...Z",
//                                                "file_path": "...", "device_name": "..." } } ],
//     "pagination": { "limit": 20, "offset": 0, "total": 42 } }

// A single search result row, normalized across content types for the UI.
struct SearchHit: Identifiable, Equatable {
    let id: String
    let kind: String          // "OCR" | "Audio" | "UI"
    let text: String
    let timestamp: Date
    let appName: String?
    let windowName: String?
    let frameId: Int?
}

enum SearchContentType: String, CaseIterable, Identifiable {
    case all, ocr, audio
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all:   return "All"
        case .ocr:   return "Screen"
        case .audio: return "Audio"
        }
    }
    // screenpipe expects content_type = all | ocr | audio
    var apiValue: String { rawValue }
}

enum SearchError: Error, LocalizedError {
    case badStatus(Int)
    case decode(String)
    var errorDescription: String? {
        switch self {
        case .badStatus(let c): return "screenpipe API returned HTTP \(c)."
        case .decode(let m):    return "Could not read the search response: \(m)"
        }
    }
}

enum SearchClient {
    static func baseURL(port: Int) -> URL {
        URL(string: "http://localhost:\(port)")!
    }

    // Build the GET /search request URL with the documented query params.
    static func searchURL(base: URL, query: String, contentType: SearchContentType,
                          limit: Int = 30, offset: Int = 0) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent("search"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "content_type", value: contentType.apiValue),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        return comps.url!
    }

    // Decode a raw /search payload into UI rows. Pure + public so the fixture check can call it.
    static func decode(_ data: Data) throws -> [SearchHit] {
        let resp: Response
        do {
            resp = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SearchError.decode(String(describing: error))
        }
        return resp.data.enumerated().map { index, item in
            let text = (item.content.text ?? item.content.transcription ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ts = item.content.timestamp.flatMap(parseTimestamp) ?? Date(timeIntervalSince1970: 0)
            let id = "\(item.type)-\(item.content.frameId.map(String.init) ?? "?")-\(item.content.timestamp ?? String(index))"
            return SearchHit(id: id, kind: item.type, text: text, timestamp: ts,
                             appName: item.content.appName, windowName: item.content.windowName,
                             frameId: item.content.frameId)
        }
    }

    // Live fetch against the running screenpipe API. Bearer token attached only when api-auth is on.
    static func search(port: Int, token: String?, query: String, contentType: SearchContentType,
                       limit: Int = 30) async throws -> [SearchHit] {
        let url = searchURL(base: baseURL(port: port), query: query, contentType: contentType, limit: limit)
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        if let token, !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SearchError.badStatus(http.statusCode)
        }
        return try decode(data)
    }

    // MARK: - wire DTOs

    private struct Response: Decodable { let data: [Item] }
    private struct Item: Decodable { let type: String; let content: Content }
    private struct Content: Decodable {
        let text: String?
        let transcription: String?
        let timestamp: String?
        let appName: String?
        let windowName: String?
        let frameId: Int?
        enum CodingKeys: String, CodingKey {
            case text, transcription, timestamp
            case appName = "app_name"
            case windowName = "window_name"
            case frameId = "frame_id"
        }
    }

    // screenpipe stamps ISO8601; tolerate fractional seconds and a plain form.
    private static func parseTimestamp(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
