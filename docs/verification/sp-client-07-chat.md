# Proof of done: sp-client-07 chat over history

Sub-goal 07 (retrieval-grounded chat, local-by-default, cloud opt-in). Branch `feat/sp-client-07-chat`.
**Privacy is NOT deferred: the default path must make NO network egress, verified live here.**

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | a question retrieves history (`/search`) and grounds the model prompt on it | PASS | R1 (prompt embeds moments) |
| AC2 | local Ollama by default; cloud only behind the 06 opt-in | PASS | R1 (plan routing) |
| AC3 | cloud opt-in defaults OFF | PASS | R1 |
| AC4 | **default path makes NO network egress (cloud off -> loopback only)** | PASS | R2 (live lsof witness) |
| AC5 | answers cite source moments (jump-to-timeline) | PASS | grep (MessageView sources) |
| AC6 | app builds with Chat wired | PASS | R3 |

## Recorded run (literal)

    Command: swiftc app/Sources/ChatEngine.swift app/Sources/LLMSettings.swift app/Sources/SearchClient.swift scripts/verify-chat.swift -o /tmp/sp-chat && /tmp/sp-chat
    Exit: 0   (OK: opt-in default OFF; default + cloud-off paths are loopback (NO egress); cloud host reached only when opted in; retrieval loopback; prompt grounded on moments)

    Command: bash scripts/verify-chat-no-egress.sh
    Exit: 0   (peer addresses observed: 127.0.0.1; OK: cloud OFF default-path chat made NO non-loopback connection)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS.

### NEGATIVE CONTROL

Two falsifiers: (1) R1 asserts a cloud-opted-in plan is NOT loopback and IS a cloud host, so the
loopback/egress discriminator genuinely distinguishes (it is not hardwired to "loopback=true").
(2) R2's lsof witness would FAIL if the cloud-off chat opened any non-loopback socket; the prior run
with a buggy (un-`-a`'d) lsof correctly showed the check CAN go red. So a green R2 means the default
path truly stayed on loopback.

## No-egress witness (REQUIRED, the privacy invariant)

`scripts/verify-chat-no-egress.sh` runs the DEFAULT-path chat (local provider, cloud opt-in OFF) in a
loop and watches the process's real TCP connections with `lsof -nP -a -p <pid> -iTCP`. With cloud
off, the only peer observed is `127.0.0.1` (the local Ollama). Any non-loopback peer fails the check.
This is enforced in code by `ChatEngine.plan` (loopback unless `LLMSettings.willEgress`, which needs a
cloud provider AND the opt-in on) plus a hard `ChatError.egressBlocked` guard in `ask`.

## Live-model note

Local Ollama is reachable on this host (`localhost:11434`) but has no model pulled, so a real
generated answer is `[LIVE-UNAVAILABLE: no Ollama model installed]`; the retrieval grounding, the
request shape, the routing, and the no-egress property are all fully verified. A real answer is part
of Han's end review once a model is pulled.

## Rollback

Additive feature behind the Chat section; no persisted state of its own (it reads 06 settings + the
local APIs). To roll back: `git revert` this commit, or remove `ChatView.swift` / `ChatEngine.swift`
and restore the `ChatSurface` stub. With cloud off there is no egress; with cloud on, egress is the
user's explicit, warned choice and the key comes from the Keychain.
