# Proof of done: API auth token (Search/Timeline/Chat work against the live backend)

Found by live-verifying issue 3: screenpipe's local API has **auth on by default**, so Search /
Timeline / Chat all failed with HTTP 403 because the app only looked for the token in its own config
file. Branch `fix/sp-client-api-auth`.

## Fix

- `Backend.apiToken()` resolves the token: config `SCREENPIPE_API_TOKEN` first, else
  `screenpipe auth token` (cached). Search / Timeline / Chat now pass it.
- Timeline's frame image (`AsyncImage`, which cannot set a bearer header) now carries the token as
  the `?api_key=` query param, which `/frames/<id>` accepts.
- The 401/403 error message now tells the user to get the token from `screenpipe auth token`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | Search returns real rows from the LIVE auth-enabled API | PASS | R1 (5 rows, app=Zed) |
| AC2 | without a token the request fails with the auth-specific error | PASS | R1 NEGATIVE CONTROL |
| AC3 | the frame-image URL carries the token (AsyncImage works under auth) | PASS | R1 (`/frames/<id>?api_key=`) |
| AC4 | token resolution prefers config, falls back to `screenpipe auth token` | PASS | grep |
| AC5 | builds | PASS | R2 |

## Recorded run (literal)

    Command: TOKEN=$(screenpipe auth token); swiftc app/Sources/SearchClient.swift scripts/verify-search-live.swift -o /tmp/sp-live && /tmp/sp-live "$TOKEN"
    Exit: 0   (LIVE OK: 5 rows; row0 app=Zed frame=4291 ; frame image URL: http://localhost:3030/frames/4279?api_key=...)

    Command: /tmp/sp-live          # no token, negative control
    Exit: 1   (LIVE: screenpipe needs an API token (the local API has auth on) ...)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS, verified against the **live, running, auth-enabled** screenpipe API.

### NEGATIVE CONTROL

R1 run without a token exits non-zero with the auth error (HTTP 403). The with-token run returns
real rows. So the token is genuinely required + genuinely works; this is not a fixture.

## Live findings confirmed (issue 3)

- `/search` response shape matches the decoder (no decoder change needed).
- `/frames/<id>` returns a real JPEG (200) and accepts `?api_key=` (the frame endpoint I had only
  assumed before is correct).
- Capture is healthy (`/health`: frame_status ok, 93+ frames). Status/Pipes/Settings work without
  the API (config/CLI/Keychain). Chat retrieval now authenticates; the model answer still needs a
  local Ollama model pulled (operator action, a download).

## Rollback

`git revert`, or restore the `cfg["SCREENPIPE_API_TOKEN"]`-only lookup in the three views and drop
`Backend.apiToken()` + the `token:` param on `frameImageURL`. No persisted state (the token is read
from the user's existing screenpipe install).
