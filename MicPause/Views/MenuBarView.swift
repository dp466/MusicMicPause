import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            MicPauseAmbientBackdrop(tint: presentation.tint)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45),
                    value: presentation.tint
                )

            ScrollView {
                VStack(spacing: 16) {
                    header
                    statusHero
                    monitoringButton
                    glassCardStack
                    footer
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 420, height: 580)
        .background(.ultraThinMaterial)
        .onAppear {
            model.loginItemManager.refresh()
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.18)) {
                hasAppeared = true
            }

            Task {
                await model.refreshAutomationPermission()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(presentation.tint.opacity(0.14))

                MicPauseBrandMark(tint: presentation.tint)
                    .padding(8)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Mic Pause")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("Quiet music. Clear conversations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(presentation.tint)
                .frame(width: 8, height: 8)
                .shadow(color: presentation.tint.opacity(0.7), radius: 5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 2)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -6)
    }

    private var statusHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(presentation.tint.opacity(0.12))
                    .frame(width: 104, height: 104)

                Circle()
                    .stroke(presentation.tint.opacity(0.24), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Image(systemName: presentation.symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(presentation.tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(hasAppeared ? 1 : 0.92)

            VStack(spacing: 5) {
                Text(presentation.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))

                Text(presentation.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .micPauseGlass(tint: presentation.tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title). \(presentation.detail)")
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
    }

    @ViewBuilder
    private var monitoringButton: some View {
        if #available(macOS 26.0, *) {
            monitoringButtonContent
                .buttonStyle(.glassProminent)
                .tint(presentation.tint)
        } else {
            monitoringButtonContent
                .buttonStyle(.borderedProminent)
                .tint(presentation.tint)
        }
    }

    private var monitoringButtonContent: some View {
        Button {
            withAnimation(.snappy) {
                model.settings.monitoringEnabled.toggle()
            }
        } label: {
            Label(
                model.settings.monitoringEnabled ? "Pause Monitoring" : "Start Monitoring",
                systemImage: model.settings.monitoringEnabled ? "pause.fill" : "play.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
        }
        .controlSize(.large)
        .keyboardShortcut(.space, modifiers: [])
        .help(
            model.settings.monitoringEnabled
                ? "Stop watching microphone activity"
                : "Start watching microphone activity"
        )
    }

    @ViewBuilder
    private var glassCardStack: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                cardContents
            }
        } else {
            cardContents
        }
    }

    private var cardContents: some View {
        VStack(spacing: 16) {
            playbackCard
            healthCard
        }
    }

    private var playbackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Playback", systemImage: "music.note")
                .font(.headline)

            Toggle(
                "Resume Apple Music automatically",
                isOn: Binding(
                    get: { model.settings.automaticResume },
                    set: { model.settings.automaticResume = $0 }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("RESUME DELAY")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Picker(
                    "Resume delay",
                    selection: Binding(
                        get: { model.settings.resumeDelay },
                        set: { model.settings.resumeDelay = $0 }
                    )
                ) {
                    ForEach(ResumeDelay.allCases) { delay in
                        Text(delay.compactTitle).tag(delay)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.settings.automaticResume)
            }
        }
        .padding(16)
        .micPauseGlass()
    }

    private var healthCard: some View {
        VStack(spacing: 13) {
            healthRow(
                icon: "mic.fill",
                title: "Microphone",
                value: model.microphoneMonitor.deviceName,
                tint: presentation.tint
            )

            Divider()

            healthRow(
                icon: automationIcon,
                title: "Apple Music access",
                value: model.automationPermission.label,
                tint: automationTint
            )
        }
        .padding(16)
        .micPauseGlass()
    }

    private func healthRow(
        icon: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",")

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }

    private var presentation: StatusPresentation {
        guard model.settings.monitoringEnabled else {
            return StatusPresentation(
                title: "Monitoring is paused",
                detail: "Start monitoring whenever you want Mic Pause to watch your microphone.",
                symbol: "pause.fill",
                tint: .secondary
            )
        }

        switch model.playbackCoordinator.state {
        case .disabled:
            return StatusPresentation(
                title: "Getting ready",
                detail: "Mic Pause is preparing microphone monitoring.",
                symbol: "ellipsis",
                tint: .secondary
            )
        case .micInactive:
            return StatusPresentation(
                title: "Ready when you speak",
                detail: "Your microphone is quiet. Apple Music can keep playing.",
                symbol: "checkmark",
                tint: .mint
            )
        case .micActive:
            return StatusPresentation(
                title: "Microphone in use",
                detail: "Mic Pause is watching Apple Music while your microphone is active.",
                symbol: "mic.fill",
                tint: .orange
            )
        case .pausedByUtility:
            return StatusPresentation(
                title: "Music gently paused",
                detail: "Apple Music will resume when the microphone becomes inactive.",
                symbol: "pause.fill",
                tint: .pink
            )
        case .unavailable(let reason):
            return StatusPresentation(
                title: "Needs your attention",
                detail: reason,
                symbol: "exclamationmark.triangle.fill",
                tint: .red
            )
        }
    }

    private var automationIcon: String {
        switch model.automationPermission {
        case .granted:
            "checkmark.circle.fill"
        case .denied, .unavailable:
            "exclamationmark.triangle.fill"
        case .notDetermined:
            "questionmark.circle"
        }
    }

    private var automationTint: Color {
        switch model.automationPermission {
        case .granted:
            .mint
        case .denied, .unavailable:
            .red
        case .notDetermined:
            .orange
        }
    }
}

private struct StatusPresentation {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

private extension ResumeDelay {
    var compactTitle: String {
        switch self {
        case .immediately:
            "Now"
        case .oneSecond:
            "1 sec"
        case .twoSeconds:
            "2 sec"
        case .fiveSeconds:
            "5 sec"
        }
    }
}
