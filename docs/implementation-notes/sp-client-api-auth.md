# Implementation notes: API auth token (issue 3 live-verification fix)

Branch `fix/sp-client-api-auth` off `feat/sp-client-menubar-icon`.

## What live verification found

With the real screenpipe capture running, `/search` returned HTTP **403 unauthorized**: the local
API has auth ON by default and wants `Authorization: Bearer <key>` where the key comes from
`screenpipe auth token`. The app only read `SCREENPIPE_API_TOKEN` from its own config (which the
user does not set), so Search / Timeline / Chat were all broken against a real backend. The decoder
shape + the `/frames/<id>` endpoint were both confirmed CORRECT against the live API (no change).

## Fix

- `Backend.apiToken()`: config `SCREENPIPE_API_TOKEN` -> else `screenpipe auth token` (cached for
  the session). The three views resolve the token through it, off the main thread.
- `SearchClient.frameImageURL(..., token:)`: `AsyncImage` can't set a bearer header, but `/frames`
  accepts the token as `?api_key=` (verified live: `?api_key`/`?token`/`?auth` all 200). Timeline
  passes the resolved token so the frame image loads under auth.
- Friendlier 401/403 error pointing at `screenpipe auth token`.

## Decisions

- Reinstated `Backend.apiToken()` (the concurrent-writer agent had added then reverted this during
  02; live testing proved it is actually required).
- Token cached for the session (resolving it shells out to the CLI). If the user rotates the token
  mid-session, a relaunch re-resolves; acceptable for a desktop app.
- Did not change the decoder or the frame endpoint, both verified correct live.

## Verification

- `app/build.sh` -> BUILD SUCCEEDED.
- LIVE: `SearchClient.search` against the running API returns 5 real rows with the token, the
  auth error without it (`scripts/verify-search-live.swift`). Frame URL carries `?api_key=`.
