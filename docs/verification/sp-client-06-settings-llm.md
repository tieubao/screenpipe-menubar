# Proof of done: sp-client-06 LLM settings

Sub-goal 06 (provider/model/endpoint + cloud key in Keychain + off-by-default opt-in). Loop type:
stateful (Keychain + UserDefaults persistence). Branch `feat/sp-client-06-settings-llm`.
**Privacy invariant: the cloud key lives ONLY in the Keychain; cloud opt-in is off by default.**

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | cloud opt-in defaults OFF (local is the default safe path) | PASS | R1 |
| AC2 | the cloud API key is NEVER written to UserDefaults or the config file | PASS | R1 + grep |
| AC3 | the key is stored via the Keychain API only | PASS | grep (SecItem only in KeychainStore) + R1 round-trip |
| AC4 | provider/model/endpoint persist (non-secrets) | PASS | R1 |
| AC5 | app builds with the Settings surface wired | PASS | R2 |

## Recorded run (literal)

    Command: swiftc app/Sources/LLMSettings.swift app/Sources/KeychainStore.swift scripts/verify-llm-settings.swift -o /tmp/sp-llm && /tmp/sp-llm
    Exit: 0   (OK: cloud opt-in default OFF; non-secrets persist; secret ABSENT from UserDefaults; keychain round-trip OK)

    Command: bash app/build.sh
    Exit: 0   (** BUILD SUCCEEDED **)

VERDICT: PASS.

### NEGATIVE CONTROL (privacy)

R1 saves a settings object with `cloudEnabled = true` AND stores a recognizable secret
(`sk-ant-TESTKEY-...`), then scans the entire UserDefaults domain for that string and FAILS if it
appears. So a green R1 means the key genuinely did not leak into UserDefaults; if `LLMSettings.save`
ever wrote the key, R1 would exit non-zero. The Keychain round-trip (set -> get == secret -> delete
-> absent) further proves the key is held in the Keychain, not invented.

### Grep proofs

- `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete` appear ONLY in `KeychainStore.swift`.
- `apiKeyInput` (the key field) flows only to `KeychainStore.set` and is then cleared; it is never
  passed to `UserDefaults` or `ConfigStore`.
- `LLMSettings.save` writes only `llm.provider`/`llm.model`/`llm.ollamaEndpoint`/`llm.cloudEnabled`.

## Rollback

Settings persist in UserDefaults (`llm.*`) + the Keychain (service `app.screenpipe.menubar`). To
roll back: `git revert` this commit, or remove `SettingsLLMView.swift` / `LLMSettings.swift` /
`KeychainStore.swift` and restore the `SettingsSurface` stub. To purge stored state:
`defaults delete app.screenpipe.menubar` and remove the `app.screenpipe.menubar` Keychain items
(the Remove key button does the latter per provider). No egress occurs from this surface; the key
is only used by Chat (07) when the user has explicitly opted in.
