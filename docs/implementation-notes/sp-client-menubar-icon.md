# Implementation notes: menu bar icon

Replace the bare colored dot with a product-identity mark. Branch `feat/sp-client-menubar-icon`.

## Design (from the Apple-HIG designer subagent)

- **Mark**: a "memory-ring", a clock whose hour ring is 12 capture-dots, hands at ~10:10. Reads as
  "a timeline assembled from continuous screen snapshots" (the app's identity), where a bare dot
  read as a generic status light.
- **State encoding**: the glyph shape is constant; state = glyph opacity (full when capturing,
  0.55 when not) + ONE colored status dot bottom-right (green/yellow/red; absent for unknown). Color
  lives on a single element; opacity is a redundant, color-independent channel.
- Per-state VoiceOver descriptions; no reliance on color alone.

## Implementation decisions

- **Drawn programmatically** (NSBezierPath in a dynamic `NSImage(size:flipped:)`), NOT a `.symbolset`
  asset: the repo has no asset catalog, and a custom glyph avoids adding one (build stays simple).
  Geometry follows the spec exactly (ring R=0.40s, dot d=0.072s, hands w=0.055s at 300 deg/60 deg).
- **Non-template image**: a template image is forced monochrome and would kill the colored status
  dot. The glyph is drawn in `NSColor.labelColor` (resolves to the status item's drawing appearance)
  so it still adapts to light/dark bars; the status dot keeps its color. Tradeoff vs the designer's
  ideal (template glyph + an overlay subview on the status button): SwiftUI `MenuBarExtra` does not
  expose the `NSStatusItem.button` to attach a subview, so the single-dynamic-image composite is the
  clean path. Cost: no automatic invert on click-highlight (the old icon lacked that too); the
  colored dot stays visible regardless.
- `CaptureState` gained `glyphDimmed` / `statusDotColor` / `accessibility`; the legacy `color` +
  `label` stay (popover header still uses them).
- Pulse animation: not implemented (designer marked it "gravy, off by default").

## Verification

- `app/build.sh` -> BUILD SUCCEEDED.
- `scripts/render-icons.swift` renders each state to `/tmp/icon-*.png` (10x). Visual confirm: ok =
  full-ink clock + green dot; attention = full-ink + yellow dot; fail = dimmed + red dot; unknown =
  dimmed + no dot. The four states are distinguishable by both the dot and the opacity channel.
- Final look in the live menu bar (light/dark/tinted bars) is Han's end review.
