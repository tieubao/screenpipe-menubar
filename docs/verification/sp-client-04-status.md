# Proof of done: sp-client-04 status surfaces

Sub-goal 04 (Redaction/PII + MCP status panels, values sourced not hardcoded). Branch
`feat/sp-client-04-status`.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | redaction values parsed from the real launcher (backend, labels, text+image flags) | PASS | R1 |
| AC2 | values are NOT hardcoded (a launcher with no flags yields nothing) | PASS | R1 NEGATIVE CONTROL |
| AC3 | MCP client detection reflects config content | PASS | R1 (claude=on, codex=off) |
| AC4 | MCP setup action wired (`screenpipe mcp setup`) | PASS | grep `Backend.mcpSetup` |
| AC5 | panels render from config files (graceful when capture is paused) | PASS | implementation-notes |
| AC6 | app builds with Status wired | PASS | R2 |

## Recorded run (literal)

    Command: swiftc app/Sources/StatusInfo.swift scripts/verify-status.swift -o /tmp/sp-status && /tmp/sp-status
    Exit: 0   (OK: redaction backend=local, 10 labels, text+image on, 13 patterns; MCP detection flips (claude=on, codex=off))

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS.

### NEGATIVE CONTROL

The check is falsifiable and embedded in R1: it writes a fake launcher with NO pii flags and asserts
`labels.isEmpty && !enabled`; if the parser invented values instead of reading them, R1 exits
non-zero. It also asserts a Codex config WITHOUT "screenpipe" reports `configured == false` (so the
MCP detection is not hardcoded-on). R1 green therefore means the values are genuinely sourced from
the launcher + configs.

## Source-of-truth note

PII labels + backend are parsed from the installed capture launcher
(`~/.local/bin/screenpipe-capture`, dev fallback `bin/screenpipe-capture`):
`--pii-backend local`, `--pii-redaction-labels secret,person,email,phone,address,id,sensitive,us_ssn,credit_card,iban`,
`--use-pii-removal`, `--async-image-pii-redaction`. Bundled pattern count from
`patterns/secrets.json` (13). MCP clients scanned read-only from `~/.claude.json`, Claude Desktop
config, `~/.codex/config.toml`. Redaction model identities are described honestly (on-device text
NER + image redaction) since screenpipe does not expose a model-version query.

## Rollback

Read-only panels, no state mutation, no egress. To roll back: `git revert` this commit, or remove
`StatusView.swift` / `StatusInfo.swift` and restore the `StatusSurface` stub in `MainWindowView.swift`.
The only action is `screenpipe mcp setup` (already existed via `Backend.mcpSetup`), which writes the
user's own MCP client config and is idempotent.
