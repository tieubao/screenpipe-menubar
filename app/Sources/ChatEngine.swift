import Foundation

// The chat model call, grounded on retrieved history. Foundation-only so the no-egress + grounding
// proofs run headlessly. The privacy invariant is enforced HERE: with the cloud opt-in off, the
// only host ever contacted is the user's own Ollama endpoint (localhost by default), never a cloud
// provider. `ask` hard-throws if a cloud host would be hit without an explicit opt-in.

struct ChatPlan: Equatable {
    let endpointURL: URL
    let willEgress: Bool      // true ONLY for a cloud provider with the 06 opt-in ON
    let badge: String         // the always-visible privacy badge
}

enum ChatError: Error, LocalizedError {
    case egressBlocked
    case badStatus(Int)
    case noContent
    case localUnreachable
    var errorDescription: String? {
        switch self {
        case .egressBlocked:   return "Blocked: a cloud request was attempted without opting in."
        case .badStatus(let c): return "The model returned HTTP \(c)."
        case .noContent:       return "The model returned no answer."
        case .localUnreachable: return "No local model is reachable. Start Ollama, or turn on a cloud provider in Settings."
        }
    }
}

enum ChatEngine {
    // Resolve where the model call goes. LOOPBACK / the user's own Ollama unless they opted into cloud.
    static func plan(_ s: LLMSettings) -> ChatPlan {
        if s.willEgress {
            return ChatPlan(endpointURL: cloudURL(s.provider), willEgress: true,
                            badge: "Cloud: \(s.provider.title)")
        }
        return ChatPlan(endpointURL: ollamaChatURL(s.ollamaEndpoint), willEgress: false,
                        badge: "Local, on-device")
    }

    static func ollamaChatURL(_ endpoint: String) -> URL {
        (URL(string: endpoint) ?? URL(string: "http://localhost:11434")!).appendingPathComponent("api/chat")
    }

    static func cloudURL(_ p: LLMProvider) -> URL {
        switch p {
        case .openai: return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .claude, .local: return URL(string: "https://api.anthropic.com/v1/messages")!
        }
    }

    static func isLoopback(_ url: URL) -> Bool {
        let h = (url.host ?? "").lowercased()
        return h == "localhost" || h == "127.0.0.1" || h == "::1" || h == "[::1]"
    }

    static func isCloudHost(_ url: URL) -> Bool {
        let h = (url.host ?? "").lowercased()
        return h.contains("anthropic.com") || h.contains("openai.com")
    }

    // Build a prompt that grounds the model on the retrieved moments and asks it to cite times.
    static func groundedPrompt(question: String, context: [SearchHit]) -> String {
        if context.isEmpty {
            return "Answer ONLY from the user's screen history. There is no relevant history for "
                + "this question, so say you could not find anything. Question: \(question)"
        }
        let iso = ISO8601DateFormatter()
        let moments = context.prefix(12).map { hit -> String in
            let when = iso.string(from: hit.timestamp)
            let app = hit.appName.map { " [\($0)]" } ?? ""
            return "- (\(when))\(app) \(hit.text)"
        }.joined(separator: "\n")
        return """
        You answer questions about the user's own screen + audio history. Use ONLY the moments
        below; do not invent. Cite the timestamp of any moment you rely on. If the moments do not
        contain the answer, say so.

        Moments:
        \(moments)

        Question: \(question)
        """
    }

    // The model call. Throws egressBlocked if a cloud host would be contacted without opt-in.
    static func ask(question: String, settings: LLMSettings, apiKey: String?,
                    context: [SearchHit]) async throws -> String {
        let p = plan(settings)
        if isCloudHost(p.endpointURL) && !settings.willEgress { throw ChatError.egressBlocked }
        let prompt = groundedPrompt(question: question, context: context)
        if settings.willEgress {
            return try await askCloud(url: p.endpointURL, provider: settings.provider,
                                      model: settings.effectiveModel, apiKey: apiKey ?? "", prompt: prompt)
        } else {
            return try await askOllama(url: p.endpointURL, model: settings.effectiveModel, prompt: prompt)
        }
    }

    // MARK: local (Ollama)

    private static func askOllama(url: URL, model: String, prompt: String) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [["role": "user", "content": prompt]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw ChatError.localUnreachable }
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ChatError.badStatus(http.statusCode)
        }
        // Ollama /api/chat non-stream: { message: { content }, ... }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = obj["message"] as? [String: Any],
              let content = message["content"] as? String else { throw ChatError.noContent }
        return content
    }

    // MARK: cloud (gated)

    private static func askCloud(url: URL, provider: LLMProvider, model: String,
                                 apiKey: String, prompt: String) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let body: [String: Any]
        switch provider {
        case .openai:
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = ["model": model, "messages": [["role": "user", "content": prompt]]]
        default: // claude
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": model, "max_tokens": 1024,
                    "messages": [["role": "user", "content": prompt]]]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ChatError.badStatus(http.statusCode)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChatError.noContent
        }
        // OpenAI: choices[0].message.content ; Claude: content[0].text
        if let choices = obj["choices"] as? [[String: Any]],
           let m = choices.first?["message"] as? [String: Any], let c = m["content"] as? String { return c }
        if let content = obj["content"] as? [[String: Any]], let t = content.first?["text"] as? String { return t }
        throw ChatError.noContent
    }
}
