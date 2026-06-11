# Implementation notes: sp-client-02 search

Sub-goal: `_meta/megagoals/screenpipe-client/goals/02-search.md`. Branch `feat/sp-client-02-search`
off `feat/sp-client-01-window`.

## Decisions

- **`ClientRouter` (ObservableObject) replaces 01's local `@State selection`.** Jump-to-frame needs
  one surface to route to another, so window selection moved into a shared router injected via
  `.environmentObject`. `router.jumpToTimeline(date:frameId:)` sets a `TimelineTarget` and switches
  to `.timeline`; sub-goal 03 reads/clears the target. This is a small refactor of 01, fine in a
  linear stack.
- **`SearchClient` is Foundation-only** (no SwiftUI) so the decode path compiles + runs headlessly
  (`scripts/verify-search-decode.swift` + `fixtures/search-response.json`). Models screenpipe's
  documented `GET /search` schema: `data[].type` + `content{ text | transcription, timestamp,
  app_name, window_name, frame_id }`, normalized to `SearchHit`. Audio rows map `transcription` ->
  `text`.
- **Port from `ConfigStore` (`SCREENPIPE_PORT`, default 3030)**, optional bearer token from
  `SCREENPIPE_API_TOKEN` (api-auth is off by default; header only set when present). No new daemon.
- **Debounced** via a cancellable `Task` + 300ms sleep (no request per keystroke). Four states:
  idle / loading / empty / error, all designed placeholders.

## Headless verification (close-the-loop)

- `app/build.sh` -> BUILD SUCCEEDED.
- `swiftc app/Sources/SearchClient.swift scripts/verify-search-decode.swift` -> decodes the fixture
  to 3 rows; asserts request URL has `/search? q content_type limit offset`, OCR field mapping
  (Safari/OCR/frame 48213), and audio transcription mapping. **rc=0.**
- greps confirm: 3 states, `Task.sleep` debounce, `router.jumpToTimeline` wiring, `content_type`
  param, config-sourced port.

## Live-API note

The screenpipe API server was not running on the Air during the build (no `:3030` listener), so
decoding was verified against a fixture matching screenpipe's documented `/search` schema rather
than a live response. The request shape matches the documented params; first live run will confirm
end-to-end. (The goal explicitly allows fixture verification.)

## Incident: concurrent writer (resolved)

Mid-build, a second agent wrote a parallel sub-goal-02 design into the same checkout on this branch
(`Client.swift` = `ClientModel`+`LocalAPI`, `Search.swift`, a `Backend.apiToken()` addition),
breaking the build. Escalated to NOTES.md `## Active blockers` per the contract; did not commit the
mix or delete the other agent's files. The other writer then withdrew (removed its files, reverted
`Backend.swift`, opened no PR), the tree returned to only this run's changes, and the build went
green. Continued with this run's design. `HealthMonitor.configuredPort()` is a committed base method
(f4c94fd), not foreign; the parallel `Client.swift` had merely called it from a nonisolated context.
