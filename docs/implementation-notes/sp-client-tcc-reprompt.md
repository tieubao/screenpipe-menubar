# Implementation notes: fix Screen Recording re-prompt

Issue: clicking the menu bar app re-prompts for Screen Recording on every open, despite the grant.

## Root cause

The popover's `onAppear` calls `HealthMonitor.refreshDetails()`, which spawns the `screenpipe` CLI
(`screenpipe status` + `screenpipe doctor`) on EVERY open. `screenpipe doctor` probes Screen
Recording. When a GUI app spawns a child that touches a TCC-gated resource, macOS attributes the
check to the **responsible process** = the menu bar app. The app itself was never granted Screen
Recording (only the `screenpipe` BINARY was, via `install.sh`'s per-binary flow), so macOS prompts
the app every time. Ad-hoc signing makes any per-app grant unstable too, but the real trigger is the
child spawn.

## Fix

Spawn the CLI with **TCC responsibility disclaimed** (`responsibility_spawnattrs_setdisclaim`), so
the child (`screenpipe`) becomes its own responsible process and ITS own grant applies, never the
app's. This is the standard macOS remedy for "a GUI app launches a CLI that has its own TCC grant"
(used by Homebrew, terminal multiplexers, etc.). `DisclaimedSpawn.run` uses `posix_spawn` +
`posix_spawnattr` with the disclaim flag; `Backend.run` routes all its tool spawns through it
(disclaiming is safe + correct for every local tool it runs, and fixes status/doctor/mcp at once).

## Decisions / tradeoffs

- Disclaim ALL `Backend.run` spawns (not just doctor): simpler, and every callee is a local tool
  that should run under its own identity. No behavior change beyond TCC attribution.
- `responsibility_spawnattrs_setdisclaim` is a libSystem symbol declared via `@_silgen_name` (no
  public header). It is stable + widely used; the alternative (reading readiness purely from the
  /health HTTP API and never spawning doctor) would lose the doctor's permission/dep detail.
- Did NOT change the refresh cadence (still status+doctor on open); the disclaim removes the prompt
  without altering what the popover shows.

## Verification

The prompt itself is observed live (Han clicks the menu bar app, no re-prompt). Headless: build
green + the spawn path uses the disclaim attr (grep) + a spawn smoke test (run a local tool through
DisclaimedSpawn and confirm output + exit captured). The live no-prompt confirmation is Han's.
