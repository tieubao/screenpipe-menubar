// Runs the DEFAULT-path chat (local settings, cloud opt-in OFF) in a loop for a few seconds so an
// external `lsof` can witness that it only ever connects to loopback. Used by verify-chat-no-egress.sh.
// Compile with ChatEngine + LLMSettings + SearchClient.

import Foundation

@main
enum NoEgressRunner {
    static func main() async {
        let s = LLMSettings.default               // local provider, localhost endpoint, cloud OFF
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            // retrieval over the local /search API (loopback); errors are fine, the point is the socket
            _ = try? await SearchClient.search(port: 3030, token: nil, query: "noegress-probe",
                                               contentType: .all, limit: 3)
            // the model call: local Ollama (loopback). ask() also hard-blocks any cloud host when not opted in.
            _ = try? await ChatEngine.ask(question: "noegress-probe", settings: s, apiKey: nil, context: [])
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        print("ran default-path chat loop")
    }
}
