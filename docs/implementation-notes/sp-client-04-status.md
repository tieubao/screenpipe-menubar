# Implementation notes: sp-client-04 status surfaces

Sub-goal: `goals/04-status-surfaces.md`. Branch `feat/sp-client-04-status` off `feat/sp-client-03-timeline`.

## Decisions

- **Values are parsed from the real capture launcher, not hardcoded.** `StatusInfo.redaction` reads
  `~/.local/bin/screenpipe-capture` (dev fallback `bin/screenpipe-capture`) for `--pii-backend`,
  `--pii-redaction-labels`, `--use-pii-removal`, `--async-image-pii-redaction`; pattern count from
  `patterns/secrets.json`. This satisfies the "sourced, not hardcoded" requirement and a negative
  control proves it (a flag-less launcher yields nothing).
- **MCP detection is read-only**: scans `~/.claude.json`, Claude Desktop config, `~/.codex/config.toml`
  for a `screenpipe` reference; reports configured / present-but-not-wired / no-config. The only
  mutating action is the existing `Backend.mcpSetup` (`screenpipe mcp setup`), idempotent.
- **Model identities described honestly** (on-device text NER + image redaction model) because
  screenpipe exposes no model-version query; the panel also carries the honest-limit note ("reduces
  leaks, not a guarantee").
- **Panels read config files**, so they render correctly while capture is paused (no live daemon
  needed); a caption states this.
- `StatusInfo` is Foundation-only for the headless check.

## Headless verification

- `app/build.sh` -> BUILD SUCCEEDED.
- `swiftc app/Sources/StatusInfo.swift scripts/verify-status.swift` -> backend=local, 10 labels,
  text+image on, 13 patterns; MCP detection flips (claude=on via a screenpipe-referencing config,
  codex=off); negative control (flag-less launcher) yields empty. rc=0.
- greps confirm `StatusInfo.redaction`/`mcpClients` + `Backend.mcpSetup` wiring.

## Deviation

Redaction model version/name is a static honest description, not a queried value (screenpipe has no
such endpoint); the goal explicitly allows "a static honest description if not queryable."
