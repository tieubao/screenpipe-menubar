# Implementation notes: sp-client-07 chat

Sub-goal: `goals/07-chat.md`. Branch `feat/sp-client-07-chat` off `feat/sp-client-06-settings-llm`.
Depends on 02 (retrieval) + 06 (model settings).

## Decisions

- **Privacy is enforced in `ChatEngine`, not just the UI.** `plan(settings)` returns a loopback
  Ollama URL UNLESS `settings.willEgress` (a cloud provider AND the 06 opt-in on). `ask` adds a hard
  `ChatError.egressBlocked` guard: it refuses to contact a cloud host when not opted in. So the
  default path is loopback by construction, and the live lsof witness confirms zero non-loopback
  sockets with cloud off.
- **Grounding**: each question retrieves up to 12 moments via the 02 `SearchClient.search` (localhost
  `/search`), and `groundedPrompt` embeds them (timestamp + app + text) with an instruction to answer
  only from them and cite times. Empty context -> a "say you found nothing" prompt (no invention).
- **Always-visible privacy badge** ("Local, on-device" green / "Cloud: <provider>" orange) from
  `ChatEngine.plan`. Answers cite their source moments, each a button that jumps to the Timeline.
- `ChatEngine` is Foundation-only (model call is plain `URLSession`) so the privacy + grounding
  proofs run headlessly; the cloud key is read from the Keychain by the View only when willEgress.

## Headless verification (REQUIRED, privacy not deferred)

- `app/build.sh` -> BUILD SUCCEEDED.
- `verify-chat.swift` (construction): opt-in default OFF; default + cloud-off plan is loopback /
  no-egress; a cloud host is reached only when opted in; retrieval loopback; prompt grounded. rc=0.
- `verify-chat-no-egress.sh` (LIVE witness): runs the cloud-off default-path chat and `lsof -a -p
  <pid> -iTCP` shows only `127.0.0.1` as a peer; any non-loopback fails. rc=0.

## Gotcha

The lsof witness first failed because `lsof -p PID -iTCP` ORs its filters on macOS (it listed every
process). Fixed with `-a` to AND `-p` and `-i`. (Good accidental negative control: it proved the
check can go red.)

## Live-model note

Ollama is up on `localhost:11434` but has no model pulled, so a real answer is unavailable here; the
retrieval, routing, request shape, and no-egress property are verified. A real answer is part of
Han's end review once a model is pulled (`ollama pull llama3.2`).
