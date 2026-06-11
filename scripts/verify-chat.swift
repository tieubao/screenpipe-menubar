// Headless privacy + grounding check for sub-goal 07 (REQUIRED, not deferred):
//   swiftc app/Sources/ChatEngine.swift app/Sources/LLMSettings.swift app/Sources/SearchClient.swift \
//     scripts/verify-chat.swift -o /tmp/sp-chat && /tmp/sp-chat
//
// Proves by construction that with the cloud opt-in OFF the chat targets only loopback (no egress),
// that a cloud host is reached ONLY when the user opted in, that the opt-in defaults off, and that
// the prompt is grounded on retrieved moments. (A live socket witness is in verify-chat-no-egress.sh.)

import Foundation

@main
enum VerifyChat {
    static func main() {
        // opt-in defaults OFF
        guard LLMSettings.default.cloudEnabled == false else { fail("cloud opt-in default not OFF") }

        // default path (local, cloud off): loopback, no egress, not a cloud host
        let pd = ChatEngine.plan(LLMSettings.default)
        guard !pd.willEgress, ChatEngine.isLoopback(pd.endpointURL), !ChatEngine.isCloudHost(pd.endpointURL) else {
            fail("default path is not loopback/no-egress: \(pd)")
        }

        // a cloud PROVIDER but opt-in OFF must STILL stay local (no egress)
        var cloudOff = LLMSettings.default; cloudOff.provider = .claude; cloudOff.cloudEnabled = false
        let pco = ChatEngine.plan(cloudOff)
        guard !pco.willEgress, ChatEngine.isLoopback(pco.endpointURL), !ChatEngine.isCloudHost(pco.endpointURL) else {
            fail("cloud provider with opt-in OFF leaked egress: \(pco)")
        }

        // only an explicit opt-in routes to a cloud host
        var cloudOn = cloudOff; cloudOn.cloudEnabled = true
        let pon = ChatEngine.plan(cloudOn)
        guard pon.willEgress, ChatEngine.isCloudHost(pon.endpointURL), !ChatEngine.isLoopback(pon.endpointURL) else {
            fail("opted-in plan did not route to cloud: \(pon)")
        }

        // retrieval is loopback
        guard ChatEngine.isLoopback(SearchClient.baseURL(port: 3030)) else { fail("retrieval not loopback") }

        // grounded prompt embeds the retrieved moments + the question
        let hits = [SearchHit(id: "x", kind: "OCR", text: "deployed the worker to production",
                              timestamp: Date(timeIntervalSince1970: 1_781_000_000),
                              appName: "Ghostty", windowName: nil, frameId: 1)]
        let prompt = ChatEngine.groundedPrompt(question: "when did I deploy?", context: hits)
        guard prompt.contains("deployed the worker"), prompt.contains("Ghostty"),
              prompt.lowercased().contains("when did i deploy") else {
            fail("grounded prompt missing the retrieved context or the question")
        }
        // empty-context prompt instructs no-invention
        let empty = ChatEngine.groundedPrompt(question: "x", context: [])
        guard empty.lowercased().contains("only") else { fail("empty-context prompt not grounded") }

        print("OK: opt-in default OFF; default + cloud-off paths are loopback (NO egress); cloud host "
              + "reached only when opted in; retrieval loopback; prompt grounded on moments")
    }

    private static func fail(_ message: String, _ code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(code)
    }
}
