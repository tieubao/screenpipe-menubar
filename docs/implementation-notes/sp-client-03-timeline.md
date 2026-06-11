# Implementation notes: sp-client-03 timeline

Sub-goal: `goals/03-timeline.md`. Branch `feat/sp-client-03-timeline` off `feat/sp-client-02-search`.

## Decisions

- **Frames come from time-ranged `/search` (content_type=ocr)**, reusing `SearchHit` rather than a
  new model: each OCR row already carries timestamp + text + app/window + frame_id, which is exactly
  a timeline moment. Added `SearchClient.framesInRange(start:end:)` (sorts ascending) +
  `start_time`/`end_time` params on `searchURL`. No new daemon.
- **Frame image via `GET /frames/<id>`** (`SearchClient.frameImageURL`), loaded with `AsyncImage`.
  Best-effort: the OCR text + metadata always render from the in-memory frame, the image is an
  enhancement with a photo-placeholder fallback, so the surface is useful even if the image
  endpoint differs or auth blocks `AsyncImage` (it can't set a bearer header; api-auth is off by
  default).
- **Scrubber** is a `Slider` over the frame index (frames are in memory, so OCR/label update
  instantly); a 120ms-debounced `displayIndex` drives the image load so fast dragging doesn't fire
  an image request per step.
- **Search jump**: `onChange(router.timelineTarget)` loads a +/-1h window around the jumped time,
  lands on the nearest frame, and clears the target (consumes the jump).

## Headless verification

- `app/build.sh` -> BUILD SUCCEEDED.
- `swiftc app/Sources/SearchClient.swift scripts/verify-timeline.swift` -> 3 frames sorted, 2 with
  frame ids, time-window URL + frame-image URL shapes verified, PNG decodes via ImageIO. rc=0.
  Negative control (missing image) -> rc=1.
- greps confirm `framesInRange`, `frameImageURL`, `timelineTarget` jump+consume, `Task.sleep`
  debounce, empty/error states.

## Live-API note

Same as 02: screenpipe API not running on the Air; frame loader + image decode verified against the
documented schema + fixtures. Frame-image endpoint assumed `GET /frames/<id>` (one-line fix if live
differs).
