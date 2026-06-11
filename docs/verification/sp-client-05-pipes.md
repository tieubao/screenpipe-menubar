# Proof of done: sp-client-05 pipes

Sub-goal 05 (list + enable/disable/run/install pipes via the `screenpipe pipe` CLI). Branch
`feat/sp-client-05-pipes`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | pipe list parses real `pipe list --json` to rows (name/enabled/schedule/title) | PASS | R1 (fixture + LIVE) |
| AC2 | enable/disable/run/install argv shapes match the CLI | PASS | R1 |
| AC3 | parse is falsifiable | PASS | R1 NEGATIVE CONTROL |
| AC4 | untrusted-pipe warning + empty state present | PASS | grep |
| AC5 | app builds with Pipes section wired | PASS | R2 |

## Recorded run (literal)

    Command: swiftc app/Sources/PipesClient.swift scripts/verify-pipes.swift -o /tmp/sp-pipes && /tmp/sp-pipes fixtures/pipe-list.json <screenpipe-bin>
    Exit: 0   (OK: 7 pipes decoded (7 enabled); argv shapes ok; live=7 pipes)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS. Note R1 parsed the fixture AND the LIVE `screenpipe pipe list --json` (7 real pipes),
so the parse is verified against actual CLI output, not just a fixture.

### NEGATIVE CONTROL

Embedded in R1: `PipesClient.decode(Data("not json"))` must throw, and R1 exits non-zero if it does
not. So a green R1 means the decoder genuinely parses (it is not a stub returning canned rows).

## Source-of-truth note

The list comes from the real CLI: `screenpipe pipe list --json` -> array of `{config{name,enabled,
schedule,title,description}, is_running, last_run}`. The committed fixture `fixtures/pipe-list.json`
is the live output with the prompt bodies + provider/preset stripped (those carry personal pipe
content); the schema is unchanged. Actions: `pipe enable|disable|run <name>`, `pipe install <dir|url>`,
each reflected back by re-listing. The CLI verbs were confirmed live (`screenpipe pipe --help`).

## Rollback

Read-mostly UI; the only mutations are the user's own enable/disable/run/install actions, all
idempotent CLI calls against the user's local pipes (no app-side state, no egress). To roll back:
`git revert` this commit, or remove `PipesView.swift` / `PipesClient.swift`, the `pipes` case in
`ClientSection`, and the `.pipes` route in `MainWindowView.swift`.
