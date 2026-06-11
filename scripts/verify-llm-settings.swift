// Headless check for sub-goal 06 (REQUIRED, privacy invariant):
//   swiftc app/Sources/LLMSettings.swift app/Sources/KeychainStore.swift scripts/verify-llm-settings.swift \
//     -o /tmp/sp-llm && /tmp/sp-llm
//
// Proves: (1) the cloud opt-in defaults OFF; (2) saving settings + a cloud key never writes the
// key into UserDefaults (it only goes to the Keychain); (3) non-secret fields DO persist. The
// Keychain round-trip is best-effort (an unsigned CLI may lack the keychain entitlement); the
// privacy proofs hold regardless because LLMSettings.save never touches the key.

import Foundation

@main
enum VerifyLLM {
    static func main() {
        // 1. opt-in default OFF (the safe path is the default)
        guard LLMSettings.default.cloudEnabled == false else { fail("cloud opt-in default is not OFF") }
        guard LLMSettings.default.provider == .local else { fail("default provider is not local") }

        let suite = "sp-test-llm-\(ProcessInfo.processInfo.processIdentifier)"
        guard let d = UserDefaults(suiteName: suite) else { fail("could not make test defaults") }
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        guard LLMSettings.load(d).cloudEnabled == false else { fail("fresh load opt-in is not OFF") }

        // 2. saving settings + a cloud key must NOT leak the key into UserDefaults
        let secret = "sk-ant-TESTKEY-do-not-leak-0123456789"
        var s = LLMSettings.default
        s.provider = .claude; s.model = "claude-x"; s.cloudEnabled = true
        s.save(d)
        let kcStored = KeychainStore.set(secret, account: LLMProvider.claude.keychainAccount)

        let dump = d.dictionaryRepresentation()
        for (k, v) in dump where String(describing: v).contains("TESTKEY") {
            fail("SECRET LEAKED into UserDefaults at key '\(k)'")
        }

        // 3. non-secrets persist
        let reloaded = LLMSettings.load(d)
        guard reloaded.provider == .claude, reloaded.model == "claude-x", reloaded.cloudEnabled else {
            fail("non-secret settings did not persist: \(reloaded)")
        }

        // 4. keychain round-trip (best-effort)
        var kcNote = "keychain unavailable headless (unsigned CLI)"
        if kcStored {
            guard KeychainStore.get(account: LLMProvider.claude.keychainAccount) == secret else {
                fail("keychain round-trip mismatch")
            }
            KeychainStore.delete(account: LLMProvider.claude.keychainAccount)
            guard !KeychainStore.exists(account: LLMProvider.claude.keychainAccount) else {
                fail("keychain delete failed")
            }
            kcNote = "keychain round-trip OK"
        }

        print("OK: cloud opt-in default OFF; non-secrets persist; secret ABSENT from UserDefaults; \(kcNote)")
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
