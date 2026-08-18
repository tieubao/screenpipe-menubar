# Implementation notes: sp-client-05 pipes

Sub-goal: `goals/05-pipes.md`. Branch `feat/sp-client-05-pipes` off `feat/sp-client-04-status`.

## Decisions

- **Pipes is a NEW 6th sidebar section.** 01 locked 5 sections (Search/Timeline/Chat/Status/Settings);
  goal 05 calls Pipes a "section", so I added `case pipes` to `ClientSection` (icon `puzzlepiece`)
  and routed it. This is the natural realization; it does not disturb the other surfaces.
- **All pipe ops go through the `screenpipe pipe` CLI** (verbs confirmed live: list/install/enable/
  disable/run). `PipesClient` is Foundation-only + dependency-free (takes the binary path), so the
  parse compiles + runs headlessly AND against the live CLI. `pipe list --json` gives structured
  rows; argv builders (`actionArgs`/`installArgs`) are pure so the command shapes are verifiable
  without executing mutations on the user's real pipes.
- **Model renamed `PipeInfo`** to avoid colliding with Foundation's `Pipe`.
- **Untrusted-pipe caution** on both the header and the install-from-URL sheet ("a pipe runs code
  over your screen data; only install pipes you trust"). Install is folder (NSOpenPanel) or URL.
- **Honest empty state** ("the public pipe store is currently empty"); no fake rows.

## Headless verification

- `app/build.sh` -> BUILD SUCCEEDED.
- `swiftc app/Sources/PipesClient.swift scripts/verify-pipes.swift` -> decodes the fixture (7 pipes,
  7 enabled) AND the LIVE `screenpipe pipe list --json` (7 real pipes); enable/disable/run/install
  argv shapes correct; negative control (malformed JSON throws). rc=0.
- greps confirm `PipesClient.list/action/install` wiring, the untrusted warning, empty state.

## Notes

The committed `fixtures/pipe-list.json` is the live `pipe list --json` output with prompt bodies +
provider/preset stripped (personal pipe content); schema unchanged. The pipe-permission system UI
(Deny/Allow/Offline/Content scoping) is explicitly out of scope (deferred, in NOTES Proposed
additions).
