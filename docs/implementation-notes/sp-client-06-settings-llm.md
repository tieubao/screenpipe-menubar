# Implementation notes: sp-client-06 LLM settings

Sub-goal: `goals/06-settings-llm.md`. Branch `feat/sp-client-06-settings-llm` off `feat/sp-client-05-pipes`.

## Decisions

- **Three stores, by sensitivity**: non-secrets (provider/model/endpoint/cloudEnabled) in
  `UserDefaults` via `LLMSettings`; the cloud API key in the macOS Keychain via `KeychainStore`
  (generic password, service `app.screenpipe.menubar`, account per provider). The key NEVER goes to
  UserDefaults or the sourced config file. This is the privacy invariant and it is the REQUIRED
  headless check.
- **Local is the default and the visibly-safe path**: `LLMSettings.default.provider == .local`,
  `cloudEnabled == false`. A cloud provider reveals an explicit, off-by-default opt-in toggle + a
  plain egress warning ("Your screen history excerpts will be sent to <provider>"). Local needs no
  key and shows "Local (no data leaves your Mac)".
- **The key field is write-only**: `SecureField` bound to a transient `@State` that is written to
  the Keychain on Save and immediately cleared; the stored value is never read back into the UI
  (presence shown as "Key stored in macOS Keychain"). A Remove key button deletes it.
- `LLMSettings` + `KeychainStore` are Foundation/Security-only so the privacy proof runs headlessly
  with a throwaway UserDefaults suite.

## Headless verification (REQUIRED)

- `app/build.sh` -> BUILD SUCCEEDED.
- `swiftc app/Sources/LLMSettings.swift app/Sources/KeychainStore.swift scripts/verify-llm-settings.swift`
  -> opt-in default OFF; non-secrets persist; a stored test secret is ABSENT from the UserDefaults
  domain; Keychain round-trip (set/get/delete) OK. rc=0.
- greps: `SecItem*` only in `KeychainStore.swift`; `apiKeyInput` only flows to `KeychainStore.set`;
  `LLMSettings.save` writes only the four non-secret keys.

## Notes

The main-window Settings section is the LLM/chat model config (what Chat 07 reads); the existing
Cmd-, Preferences scene still handles capture config. Key validation against the provider is
explicitly out of scope (deferred, NOTES Proposed additions). The Keychain round-trip happened to
work for the unsigned swiftc binary on this host; the proof does not depend on it (the privacy
checks hold by construction even if Keychain access were unavailable).
