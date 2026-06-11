import SwiftUI

// LLM/chat settings: provider (Local/Claude/OpenAI), model, local endpoint, and the cloud opt-in.
// Local is the default safe path (no egress). A cloud provider requires flipping an explicit,
// off-by-default switch with a plain egress warning, and its API key is written to the Keychain
// only, never to the config file or UserDefaults, and never read back into the field.

struct SettingsLLMView: View {
    @State private var settings = LLMSettings.default
    @State private var apiKeyInput = ""
    @State private var keySaved = false
    @State private var note = ""

    var body: some View {
        Form {
            Section("Chat model") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(LLMProvider.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: settings.provider) { _ in refreshKeyState() }

                TextField("Model", text: $settings.model, prompt: Text(settings.provider.defaultModel))

                if settings.provider == .local {
                    TextField("Ollama endpoint", text: $settings.ollamaEndpoint,
                              prompt: Text("http://localhost:11434"))
                }
            }

            if settings.provider == .local {
                Section {
                    Label("Local (no data leaves your Mac).", systemImage: "lock.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Section("Cloud access") {
                    Toggle("Send my screen history to \(settings.provider.title)", isOn: $settings.cloudEnabled)
                    if settings.cloudEnabled {
                        Label(settings.provider.egressNote, systemImage: "exclamationmark.triangle")
                            .font(.callout).foregroundStyle(.orange)
                    } else {
                        Text("Off: nothing leaves your Mac. Turn on to use \(settings.provider.title).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    SecureField("API key", text: $apiKeyInput, prompt: Text(keySaved ? "Saved in Keychain" : "Paste your \(settings.provider.title) API key"))
                    HStack {
                        Label(keySaved ? "Key stored in macOS Keychain" : "No key saved",
                              systemImage: keySaved ? "key.fill" : "key")
                            .font(.caption).foregroundStyle(keySaved ? .green : .secondary)
                        Spacer()
                        if keySaved { Button("Remove key") { removeKey() }.controlSize(.small) }
                    }
                }
            }

            Section {
                HStack {
                    Button("Save") { save() }.keyboardShortcut(.defaultAction)
                    if !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { load() }
    }

    private func load() {
        settings = LLMSettings.load()
        refreshKeyState()
    }

    private func refreshKeyState() {
        keySaved = KeychainStore.exists(account: settings.provider.keychainAccount)
    }

    private func save() {
        settings.save()                       // non-secrets only
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            _ = KeychainStore.set(key, account: settings.provider.keychainAccount)
            apiKeyInput = ""                  // never keep the key in memory/UI longer than needed
            keySaved = true
        }
        note = "Saved"
    }

    private func removeKey() {
        KeychainStore.delete(account: settings.provider.keychainAccount)
        keySaved = false
        note = "Key removed"
    }
}
