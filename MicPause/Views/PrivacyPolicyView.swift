import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privacy Policy")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    policySection(
                        "Audio and microphone activity",
                        "Mic Pause reads microphone activity and capture-process identifiers reported by Core Audio. It does not access, record, analyze, save, or transmit audio."
                    )
                    policySection(
                        "Apple Music",
                        "When enabled, Mic Pause sends play, pause, and playback-state commands directly to Apple Music using macOS Automation. It does not read your music library or listening history."
                    )
                    policySection(
                        "Data collection and networking",
                        "Mic Pause does not collect personal data, include analytics or advertising, create accounts, or make network requests."
                    )
                    policySection(
                        "Preferences",
                        "Your monitoring, automatic-resume, resume-delay, and ignored-source preferences are stored locally on your Mac using system preferences. They are not shared with the developer."
                    )
                    policySection(
                        "Changes",
                        "If Mic Pause’s data practices change, this policy and the App Store privacy disclosure will be updated before the changed version is released."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .frame(width: 540, height: 500)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
