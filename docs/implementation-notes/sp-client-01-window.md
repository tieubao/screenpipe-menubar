# Implementation notes: sp-client-01 main window shell

Sub-goal: `_meta/megagoals/screenpipe-client/goals/01-main-window.md` (in ops-toolkit).
Branch `feat/sp-client-01-window` off `feat/sp-menubar-08-about-prefs` (parent stack tip, PR #7, unmerged).

## Decisions

- **New `Window(id: "main")` scene**, not `WindowGroup`. Single main window, addressable by id so
  the popover can `openWindow(id: "main")`; matches the existing About `Window` pattern. App stays
  LSUIElement (menu bar accessory), so the window shows only on demand, no Dock-icon churn (no
  `setActivationPolicy(.regular)`).
- **`ClientSection` enum** (search/timeline/chat/status/settings) carries `title` + SF Symbol
  `systemImage`; one exhaustive `switch` in `detail(for:)` does the routing, so the compiler
  enforces full coverage and the wiring is greppable.
- **Stub surfaces** (`SearchSurface` ... `SettingsSurface`) live in `MainWindowView.swift` for 01;
  later sub-goals grow each in place (02 Search, 03 Timeline, etc.). Kept as distinct top-level
  structs so each sub-goal has a clear home.
- **Popover entry** is a prominent bordered `Label("Open screenpipe", ...)` above the footer (not a
  tiny footer link), since opening the client is the headline new action. `NSApp.activate` brings
  the accessory app forward on open.
- Min size `760x480` on the split view; `.defaultSize(900x600)` on the scene.

## Headless verification (close-the-loop)

- `app/build.sh` -> **BUILD SUCCEEDED**, launchable `ScreenpipeMenubar.app` binary produced.
- enum has all 5 cases; routing switch references all 5 `*Surface()`; popover has
  `openWindow(id: "main")`; scene wires `Window("screenpipe", id: "main") { MainWindowView() }`;
  `NavigationSplitView` + min size present.
- SourceKit cross-file "cannot find type" diagnostics are noise (no xcodegen project context); the
  xcodebuild compile is the source of truth and is green.

## Deviations from spec

None material. The "Open screenpipe" entry was made a prominent bordered button rather than a
footer link (spec said "an entry"; this is a more native affordance). Look-and-feel defers to
Han's single end-of-run review per the autonomy boundary.
