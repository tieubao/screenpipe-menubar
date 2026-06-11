# Proof of done: fix Screen Recording re-prompt (TCC responsibility disclaim)

Issue: clicking the menu bar app re-prompts for Screen Recording every time, despite the grant.
Branch `fix/sp-client-tcc-reprompt`.

## Root cause -> fix

`HealthMonitor.refreshDetails()` (popover `onAppear`) spawns `screenpipe doctor`, which probes
Screen Recording. A GUI app spawning that child is the TCC **responsible process**, so macOS prompts
the app (only the `screenpipe` BINARY was granted, not the app). Fix: spawn with
`responsibility_spawnattrs_setdisclaim` so the child runs under its OWN TCC identity; the granted
`screenpipe` binary's grant applies and the app is never the one prompted. `Backend.run` now routes
all tool spawns through `DisclaimedSpawn`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | the disclaiming spawn runs a tool + captures stdout + exit status | PASS | R1 |
| AC2 | failure cases report not-ok (falsifiable) | PASS | R1 NEGATIVE CONTROL |
| AC3 | `Backend.run` routes through the disclaiming spawn; disclaim flag set | PASS | grep |
| AC4 | app builds | PASS | R2 |
| AC5 | clicking the menu bar app no longer re-prompts for Screen Recording | LIVE (Han) | observed in the end review |

## Recorded run (literal)

    Command: swiftc app/Sources/DisclaimedSpawn.swift scripts/verify-disclaim-spawn.swift -o /tmp/sp-spawn && /tmp/sp-spawn
    Exit: 0   (OK: disclaimed spawn captures stdout + exit status (echo, true, false, missing-bin))

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS (headless). AC5 is the live confirmation.

### NEGATIVE CONTROL

R1 asserts `/usr/bin/false` and a missing binary both report `ok == false`, and `/usr/bin/true`
reports `ok == true`. So the spawn genuinely reflects the child's exit status (it is not hardwired to
success); a broken spawn path would flip R1 red.

## Live confirmation (AC5)

The TCC prompt is a GUI dialog that cannot be triggered/observed headlessly. Han confirms in the end
review: open the rebuilt app, click the menu bar icon several times, no Screen Recording prompt
appears (the popover still shows readiness from `screenpipe doctor`, now run disclaimed). If a prompt
still appears, it would be attributed to `screenpipe` (its own identity), not the app, and only once.

## Rollback

Pure mechanism change (how children are spawned), no persisted state. To roll back: `git revert`, or
restore the `Process()` body in `Backend.run` and delete `DisclaimedSpawn.swift`. Behavior is
identical except TCC attribution.
