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
                        "Meeting controls and Phone calls",
                        "When you enable Meeting Assist or Phone-call detection and grant Accessibility permission, Mic Pause reads control roles, labels, enabled states, and available actions in supported meeting apps. It presses only a verified Mute or Unmute control. It may read whether Phone or FaceTime exposes an enabled Hang Up control to recognize a call, but it never presses that control."
                    )
                    policySection(
                        "System volume",
                        "Meeting Assist can temporarily lower the default output device’s software volume. It restores only the exact value it changed and leaves a manual volume change alone."
                    )
                    policySection(
                        "Feedback sounds",
                        "If enabled, Mic Pause plays brief locally generated tones for Music and meeting-microphone changes. The tones contain no microphone audio and are off by default."
                    )
                    policySection(
                        "Data collection and networking",
                        "Mic Pause does not collect personal data, include analytics or advertising, create accounts, or make network requests."
                    )
                    policySection(
                        "Preferences",
                        "Your monitoring, playback, Meeting Assist, Phone-call detection, feedback-sound, and ignored-source preferences are stored locally on your Mac using system preferences. They are not shared with the developer."
                    )
                    policySection(
                        "Changes",
                        "If Mic Pause’s data practices change, this policy and any applicable distribution privacy disclosure will be updated before the changed version is released."
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
