import SwiftUI

struct AboutView: View {
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    private let repo = URL(string: "https://github.com/tieubao/screenpipe-menubar")!
    private let upstream = URL(string: "https://github.com/mediar-ai/screenpipe")!

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: StatusIcon.image(for: .ok))
                .resizable()
                .frame(width: 44, height: 44)

            Text("screenpipe-menubar").font(.title2.weight(.semibold))
            Text("Version \(version)").font(.caption).foregroundStyle(.secondary)

            Text("Privacy-first control for screenpipe 24/7 screen memory on macOS.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                bullet("Excludes password managers, wallets, and banking windows")
                bullet("Redacts PII on-device; never persists typed or copied text")
                bullet("Encrypted at rest (FileVault); no telemetry, no cloud")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Link("Project", destination: repo)
                Link("screenpipe", destination: upstream)
            }
            .font(.caption)

            Text("MIT License \u{00B7} \u{00A9} 2026")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 340)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}")
            Text(text)
        }
    }
}
