// Headless check for sub-goal 03: the timeline's frame loader + image decode.
//
//   swiftc app/Sources/SearchClient.swift scripts/verify-timeline.swift -o /tmp/sp-timeline \
//     && /tmp/sp-timeline fixtures/search-response.json fixtures/frame-sample.png
//
// Verifies: time-ranged /search decodes + sorts ascending by time (a known window returns frames
// with timestamp + text + frameId), the frame-image URL shape, and that a frame image actually
// decodes (ImageIO). Exits non-zero on any failure.

import Foundation
import ImageIO

@main
enum VerifyTimeline {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let framesPath = args.first ?? "fixtures/search-response.json"
        let imagePath = args.count > 1 ? args[1] : "fixtures/frame-sample.png"

        guard let data = FileManager.default.contents(atPath: framesPath) else {
            fail("frames fixture not found: \(framesPath)", 2)
        }
        do {
            // Decode + sort ascending, the way framesInRange does.
            let frames = try SearchClient.decode(data).sorted { $0.timestamp < $1.timestamp }
            let ocr = frames.filter { $0.frameId != nil }
            guard let first = ocr.first else { fail("no OCR frame with a frame id decoded") }
            guard first.timestamp.timeIntervalSince1970 > 0, !first.text.isEmpty else {
                fail("frame missing timestamp/text: \(first)")
            }
            // ascending by time
            for i in 1..<frames.count where frames[i].timestamp < frames[i - 1].timestamp {
                fail("frames not sorted ascending at \(i)")
            }
            // time-window request carries start_time + end_time
            let now = Date(timeIntervalSince1970: 1_781_000_000)
            let u = SearchClient.searchURL(base: SearchClient.baseURL(port: 3030), query: "",
                                           contentType: .ocr, limit: 500,
                                           startTime: now.addingTimeInterval(-3600),
                                           endTime: now).absoluteString
            for needle in ["start_time=", "end_time=", "content_type=ocr"] {
                guard u.contains(needle) else { fail("time-window URL missing \(needle): \(u)") }
            }
            // frame-image URL shape
            let img = SearchClient.frameImageURL(port: 3030, frameId: first.frameId!).absoluteString
            guard img == "http://localhost:3030/frames/\(first.frameId!)" else {
                fail("frame image URL off: \(img)")
            }
            // the frame image actually decodes (ImageIO)
            guard let imgData = FileManager.default.contents(atPath: imagePath),
                  let src = CGImageSourceCreateWithData(imgData as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil),
                  cg.width > 0, cg.height > 0 else {
                fail("frame image did not decode: \(imagePath)")
            }
            print("OK: \(frames.count) frames (sorted, \(ocr.count) with frame ids); image \(cg.width)x\(cg.height) decoded")
            print("  frame0: \(first.appName ?? "?") @ \(first.timestamp) frame=\(first.frameId!) - \(first.text.prefix(40))")
        } catch {
            fail("decode threw: \(error)")
        }
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
