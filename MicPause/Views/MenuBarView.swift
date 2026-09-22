import AppKit
import SwiftUI

enum MenuBarPanel {
    /// The popover has to be told this before it is shown. Left to size itself,
    /// it anchors using its default 320 × 320 and then grows around that
    /// origin, pushing the panel off the screen edges.
    static let size = CGSize(width: 420, height: 580)
}

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        // Resolved once per update and handed down; every card reads the same
        // snapshot instead of recomputing it.
        let status = statusPresentation

        ZStack {
            MicPauseAmbientBackdrop(tint: status.tint)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45),
                    value: status.tint
                )

            ScrollView {
                VStack(spacing: 16) {
                    header(status)
                    statusHero(status)
                    monitoringButton(status)
                    glassCardStack(status)
                    footer
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: MenuBarPanel.size.width, height: MenuBarPanel.size.height)
        .background(.ultraThinMaterial)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.18)) {
                hasAppeared = true
            }
        }
        .task {
            await model.refreshVisibleState()
        }
    }

    private func header(_ status: StatusPresentation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.tint.opacity(0.14))

                MicPauseBrandMark(tint: status.tint)
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
                .fill(status.tint)
                .frame(width: 8, height: 8)
                .shadow(color: status.tint.opacity(0.7), radius: 5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 2)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -6)
    }

    private func statusHero(_ status: StatusPresentation) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(status.tint.opacity(0.12))
                    .frame(width: 104, height: 104)

                Circle()
                    .stroke(status.tint.opacity(0.24), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Image(systemName: status.symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(status.tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(hasAppeared ? 1 : 0.92)

            VStack(spacing: 5) {
                Text(status.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))

                Text(status.detail)
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
        .micPauseGlass(tint: status.tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title). \(status.detail)")
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
    }

    @ViewBuilder
    private func monitoringButton(_ status: StatusPresentation) -> some View {
        if #available(macOS 26.0, *) {
            monitoringButtonContent
                .buttonStyle(.glassProminent)
                .tint(status.tint)
        } else {
            monitoringButtonContent
                .buttonStyle(.borderedProminent)
                .tint(status.tint)
        }
    }

    private var monitoringButtonContent: some View {
        let isMonitoring = model.monitoringEnabled

        return Button {
            withAnimation(.snappy) {
                model.setMonitoringEnabled(!isMonitoring)
            }
        } label: {
            Label(
                isMonitoring ? "Pause Monitoring" : "Start Monitoring",
                systemImage: isMonitoring ? "pause.fill" : "play.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
        }
        .controlSize(.large)
        .keyboardShortcut(.space, modifiers: [])
        .help(
            isMonitoring
                ? "Stop watching microphone activity"
                : "Start watching microphone activity"
        )
    }

    @ViewBuilder
    private func glassCardStack(_ status: StatusPresentation) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                cardContents(status)
            }
        } else {
            cardContents(status)
        }
    }

    private func cardContents(_ status: StatusPresentation) -> some View {
        VStack(spacing: 16) {
            playbackCard
            healthCard(status)
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
                Text("RECOVERY DELAY")
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
                .disabled(
                    !model.settings.automaticResume && !model.settings.meetingAssistEnabled
                )
            }
        }
        .padding(16)
        .micPauseGlass()
    }

    private func healthCard(_ status: StatusPresentation) -> some View {
        VStack(spacing: 13) {
            healthRow(
                icon: "mic.fill",
                title: "Microphone",
                value: model.microphoneMonitor.deviceName,
                tint: status.tint
            )

            Divider()

            healthRow(
                icon: model.automationPermission.symbol,
                title: "Apple Music access",
                value: model.automationPermission.label,
                tint: model.automationPermission.tint
            )

            if model.settings.meetingAssistEnabled {
                Divider()

                healthRow(
                    icon: model.meetingAssistCoordinator.isActive
                        ? "person.wave.2.fill"
                        : "person.wave.2",
                    title: "Meeting Assist",
                    value: model.meetingAssistCoordinator.state.label,
                    tint: model.meetingAssistCoordinator.isActive ? .indigo : .mint
                )
            }
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
            Button {
                SettingsWindowController.shared.show()
            } label: {
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

    private var statusPresentation: StatusPresentation {
        guard model.monitoringEnabled else {
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
}

struct StatusPresentation {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

extension AutomationPermissionStatus {
    var symbol: String {
        switch self {
        case .granted:
            "checkmark.circle.fill"
        case .denied, .unavailable:
            "exclamationmark.triangle.fill"
        case .notDetermined:
            "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .granted:
            .mint
        case .denied, .unavailable:
            .red
        case .notDetermined:
            .orange
        }
    }
}

extension ResumeDelay {
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
