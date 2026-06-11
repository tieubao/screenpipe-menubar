# Proof of done: sp-client-03 timeline

Sub-goal 03 (scrub frames by time, preview frame + OCR, honor a Search jump). Loop type: stateful
(API frame loader + image decode). Branch `feat/sp-client-03-timeline`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | frames load for a time window, ascending by time, with timestamp + OCR text + frame id | PASS | R1 |
| AC2 | the frame image actually decodes | PASS | R1 (ImageIO 1x1) |
| AC3 | image-decode is falsifiable | PASS | R2 (negative control) |
| AC4 | time-window request + frame-image URL shapes match the API | PASS | R1 |
| AC5 | scrub debounce + empty/error states + Search-jump target | PASS | grep (implementation-notes) |
| AC6 | app builds with Timeline wired | PASS | R3 |

## Recorded run (literal)

    Command: swiftc app/Sources/SearchClient.swift scripts/verify-timeline.swift -o /tmp/sp-timeline && /tmp/sp-timeline fixtures/search-response.json fixtures/frame-sample.png
    Exit: 0   (OK: 3 frames (sorted, 2 with frame ids); image 1x1 decoded)

    Command: /tmp/sp-timeline fixtures/search-response.json /tmp/nonexistent.png   # negative control
    Exit: 1   (FAIL: frame image did not decode)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

R1 = positive (frames sorted ascending; first OCR frame has timestamp/text/frameId; the
time-window URL carries `start_time`/`end_time`/`content_type=ocr`; `frameImageURL(3030, id)` ==
`http://localhost:3030/frames/<id>`; the PNG decodes via ImageIO). R2 negative control proves the
image-decode step is falsifiable. R3 build.

## Live-API caveat

screenpipe was not running on the Air, so the frame loader is verified against the documented
`/search` (time-ranged) schema + a fixture frame image, not a live capture.
`[LIVE-UNAVAILABLE: screenpipe server not running on this host]` for the live frame round-trip; the
request/URL shapes and the decode paths are fully verified offline. The frame-image endpoint is
assumed `GET /frames/<id>` per screenpipe docs; first live run confirms it (one-line fix in
`SearchClient.frameImageURL` if the path differs).

## Rollback

Additive feature behind the Timeline section. To roll back: `git revert` this commit, or remove
`TimelineView.swift` + the `framesInRange`/`frameImageURL`/time-window additions in
`SearchClient.swift` and restore the `TimelineSurface` stub in `MainWindowView.swift`. No persisted
state; the loader issues read-only `GET /search` + `GET /frames/<id>` requests to a local port.
