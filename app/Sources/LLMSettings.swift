import Foundation

// Non-secret LLM/chat settings, persisted in UserDefaults. The cloud API key is NOT here: it lives
// only in the Keychain (KeychainStore). `cloudEnabled` defaults OFF so the local, no-egress path is
// the default. Chat (07) reads this.

enum LLMProvider: String, CaseIterable, Identifiable {
    case local, claude, openai

    var id: String { rawValue }
    var title: String {
        switch self {
        case .local:  return "Local (Ollama)"
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        }
    }
    var isCloud: Bool { self != .local }
    var keychainAccount: String { "cloud-api-key.\(rawValue)" }
    var defaultModel: String {
        switch self {
        case .local:  return "llama3.2"
        case .claude: return "claude-sonnet-4-6"
        case .openai: return "gpt-4o"
        }
    }
    var egressNote: String {
        isCloud ? "Your screen history excerpts will be sent to \(title) to answer." : ""
    }
}

struct LLMSettings: Equatable {
    var provider: LLMProvider
    var model: String
    var ollamaEndpoint: String
    var cloudEnabled: Bool           // OFF by default: nothing leaves the Mac unless turned on

    static let `default` = LLMSettings(provider: .local, model: "",
                                       ollamaEndpoint: "http://localhost:11434",
                                       cloudEnabled: false)

    // UserDefaults keys (non-secret only).
    private enum Key {
        static let provider = "llm.provider"
        static let model = "llm.model"
        static let endpoint = "llm.ollamaEndpoint"
        static let cloudEnabled = "llm.cloudEnabled"
    }

    static func load(_ d: UserDefaults = .standard) -> LLMSettings {
        var s = LLMSettings.default
        if let raw = d.string(forKey: Key.provider), let p = LLMProvider(rawValue: raw) { s.provider = p }
        s.model = d.string(forKey: Key.model) ?? ""
        if let ep = d.string(forKey: Key.endpoint), !ep.isEmpty { s.ollamaEndpoint = ep }
        // absent default = false (the safe path)
        s.cloudEnabled = d.bool(forKey: Key.cloudEnabled)
        return s
    }

    // Persists ONLY non-secret fields. The API key never passes through here.
    func save(_ d: UserDefaults = .standard) {
        d.set(provider.rawValue, forKey: Key.provider)
        d.set(model, forKey: Key.model)
        d.set(ollamaEndpoint, forKey: Key.endpoint)
        d.set(cloudEnabled, forKey: Key.cloudEnabled)
    }

    var effectiveModel: String { model.isEmpty ? provider.defaultModel : model }

    // The chat path is allowed to egress only when a cloud provider is chosen AND opt-in is on.
    var willEgress: Bool { provider.isCloud && cloudEnabled }
}
