# Proof of done: sp-client-02 search

Sub-goal 02 (search over screen history via the local screenpipe `/search` API). Loop type:
stateful (a network API client + decode). Branch `feat/sp-client-02-search`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | request hits `GET /search` with the documented params | PASS | R1 |
| AC2 | response decodes to UI rows; OCR text + audio transcription both map | PASS | R1 |
| AC3 | decode is falsifiable (bad/missing data fails) | PASS | R2, R3 (negative controls) |
| AC4 | app builds with the search surface wired in | PASS | R4 |
| AC5 | debounce + idle/loading/empty/error states + jump-to-frame present | PASS | grep (implementation-notes) |

## Recorded runs

Built `/tmp/sp-decode` via `swiftc app/Sources/SearchClient.swift scripts/verify-search-decode.swift`.

| Run | Command | Result | Verdict |
|---|---|---|---|
| R1 (positive) | `/tmp/sp-decode fixtures/search-response.json` | `OK: decoded 3 rows; request shape + field mapping verified` (row0 = OCR/Safari/frame 48213; audio transcription mapped) | PASS, rc=0 |
| R2 (negative) | `/tmp/sp-decode` on `{"data":[{"type":"OCR","content":{}}]}` | `FAIL: field mapping off ... text: ""` | RED-as-expected, rc=1 |
| R3 (negative) | `/tmp/sp-decode` on `not json` | `FAIL: decode threw: DecodingError.dataCorrupted ... not valid JSON` | RED-as-expected, rc=1 |
| R4 (build) | `bash app/build.sh` | `** BUILD SUCCEEDED **` | PASS |

The negative controls confirm the check is falsifiable: an empty content object and malformed JSON
both make the decoder fail, so a green R1 is meaningful.

### Recorded run (literal)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

    Command: swiftc app/Sources/SearchClient.swift scripts/verify-search-decode.swift -o /tmp/sp-decode && /tmp/sp-decode fixtures/search-response.json
    Exit: 0   (OK: decoded 3 rows; request shape + field mapping verified)

    Command: /tmp/sp-decode /tmp/sp-bad.json      # negative control: empty content
    Exit: 1   (FAIL: field mapping off)

    Command: /tmp/sp-decode /tmp/sp-bad2.json     # negative control: malformed JSON
    Exit: 1   (FAIL: decode threw: not valid JSON)

## Live-API caveat

The screenpipe API server was not running on the Air at build time (no `:3030` listener), so the
request/response contract is verified against a fixture matching screenpipe's documented `/search`
schema, not a live response. `[LIVE-UNAVAILABLE: screenpipe server not running on this host]` for
the end-to-end row; the request URL shape and the decode mapping are fully verified offline. First
run against a live server confirms the round trip.

## Rollback

Pure additive feature behind the Search section. To roll back: `git revert` this commit, or remove
`SearchView.swift` / `SearchClient.swift` / `ClientRouter.swift` and restore the `SearchSurface`
stub + 01's local `@State` selection in `MainWindowView.swift`. No persisted state, no migration,
no host side effects (the client only issues read-only `GET /search` requests to a local port).
