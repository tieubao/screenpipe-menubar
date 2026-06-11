# Proof of done: menu bar icon

Replace the bare colored dot with an identity mark (designer-specified). Branch
`feat/sp-client-menubar-icon`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | the icon is a product mark, not a bare dot (clock-from-capture-dots) | PASS | R1 render |
| AC2 | 4 states are distinguishable (dot color + glyph opacity) | PASS | R1 (ok green/full, fail red/dim, unknown none/dim) |
| AC3 | unknown shows NO colored verdict; fail/unknown are dimmed | PASS | R1 NEGATIVE CONTROL |
| AC4 | per-state accessibility descriptions set | PASS | grep `accessibility` |
| AC5 | builds | PASS | R2 |
| AC6 | looks right in the live menu bar (light/dark/tinted) | LIVE (Han) | end review |

## Recorded run (literal)

    Command: swiftc app/Sources/StatusIcon.swift app/Sources/CaptureState.swift scripts/render-icons.swift -o /tmp/sp-icons && /tmp/sp-icons
    Exit: 0   (wrote /tmp/icon-{ok,attention,fail,unknown}.png at 10x)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS (headless: the mark + 4-state encoding render correctly). AC6 is the live look.

### NEGATIVE CONTROL

The states are not cosmetically identical: `unknown` renders with NO status dot (absence = "no
verdict yet") and a dimmed glyph, while `ok` is full-ink with a green dot and `fail` is dimmed with a
red dot. If the state -> (opacity, dot) mapping were a no-op, the four PNGs would be identical; they
are visibly different (verified by inspecting the renders), so the encoding is real.

## Designer consult

The design (mark, state encoding, rendering, accessibility) came from an Apple-HIG designer subagent;
the implementation follows that spec. The one deviation (single dynamic non-template image vs a
template glyph + status-button overlay) is forced by SwiftUI `MenuBarExtra` not exposing the status
button, documented in the implementation notes.

## Rollback

Pure presentation. To roll back: `git revert`, or restore the previous `StatusIcon` (colored
`circle.fill`) and drop the `glyphDimmed`/`statusDotColor`/`accessibility` additions to `CaptureState`.
