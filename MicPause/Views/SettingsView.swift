import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingPrivacyPolicy = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            MicPauseAmbientBackdrop(tint: settingsTint)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45),
                    value: settingsTint
                )

            ScrollView {
                VStack(spacing: 18) {
                    header
                    glassCardStack
                }
                .padding(24)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 620, height: 680)
        .background(.ultraThinMaterial)
        .task {
            model.loginItemManager.refresh()
            await model.refreshAutomationPermission()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.14)) {
                hasAppeared = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                model.loginItemManager.refresh()
                await model.refreshAutomationPermission()
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(settingsTint.opacity(0.14))

                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(settingsTint)
                    .padding(12)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("Make Mic Pause work exactly the way you like.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                model.settings.monitoringEnabled ? "Monitoring" : "Paused",
                systemImage: model.settings.monitoringEnabled ? "waveform" : "pause.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(settingsTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(settingsTint.opacity(0.11), in: Capsule())
            .accessibilityLabel(
                model.settings.monitoringEnabled
                    ? "Microphone monitoring is enabled"
                    : "Microphone monitoring is paused"
            )
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var glassCardStack: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                cardContents
            }
        } else {
            cardContents
        }
    }

    private var cardContents: some View {
        VStack(spacing: 18) {
            generalCard
            playbackCard
            microphoneCard
            automationCard
            aboutCard
        }
    }

    private var generalCard: some View {
        settingsCard(
            icon: "switch.2",
            title: "General",
            subtitle: "Monitoring and startup behavior"
        ) {
            settingToggle(
                title: "Enable monitoring",
                detail: "Watch the selected microphone for activity.",
                isOn: Binding(
                    get: { model.settings.monitoringEnabled },
                    set: { model.settings.monitoringEnabled = $0 }
                )
            )

            Divider()

            settingToggle(
                title: "Launch at login",
                detail: "Keep Mic Pause ready whenever you sign in.",
                isOn: Binding(
                    get: { model.loginItemManager.isEnabled },
                    set: { model.loginItemManager.setEnabled($0) }
                )
            )

            if let statusMessage = model.loginItemManager.statusMessage {
                Divider()

                VStack(alignment: .leading, spacing: 9) {
                    Label(statusMessage, systemImage: loginItemStatusIcon)
                        .font(.caption)
                        .foregroundStyle(loginItemMessageColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if model.loginItemManager.requiresApproval {
                        Button("Open Login Items Settings") {
                            openLoginItemsSettings()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var playbackCard: some View {
        settingsCard(
            icon: "music.note",
            title: "Playback",
            subtitle: "Choose how Apple Music comes back"
        ) {
            settingToggle(
                title: "Resume automatically",
                detail: "Continue Apple Music after the microphone becomes inactive.",
                isOn: Binding(
                    get: { model.settings.automaticResume },
                    set: { model.settings.automaticResume = $0 }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 10) {
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
                        Text(delay.title).tag(delay)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.settings.automaticResume)
            }
        }
    }

    private var microphoneCard: some View {
        settingsCard(
            icon: "mic.fill",
            title: "Microphone Activity",
            subtitle: "Live device information"
        ) {
            statusRow(
                title: "Selected microphone",
                value: model.microphoneMonitor.deviceName,
                icon: "mic.circle.fill",
                tint: settingsTint
            )

            Divider()

            statusRow(
                title: "Current status",
                value: model.playbackCoordinator.state.label,
                icon: microphoneStatusIcon,
                tint: microphoneStatusTint
            )

            Divider()

            Label {
                Text("Mic Pause detects only whether the device is active. It never records, accesses, or transmits audio.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.mint)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var automationCard: some View {
        settingsCard(
            icon: "music.note.list",
            title: "Apple Music Automation",
            subtitle: "Permission to pause and resume playback"
        ) {
            statusRow(
                title: "Permission",
                value: model.automationPermission.label,
                icon: automationStatusIcon,
                tint: automationStatusTint
            )

            Divider()

            automationActions

            if let message = model.automationPermissionMessage {
                Label(message, systemImage: automationMessageIcon)
                    .font(.caption)
                    .foregroundStyle(permissionMessageColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("macOS asks for Automation access the first time Mic Pause controls Apple Music. Accessibility permission is never used.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutCard: some View {
        settingsCard(
            icon: "info.circle.fill",
            title: "About Mic Pause",
            subtitle: "Quiet music. Clear conversations."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(versionDescription)
                        .font(.callout.weight(.medium))
                }

                Spacer()

                Button("Privacy Policy…") {
                    showingPrivacyPolicy = true
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settingsTint)
                    .frame(width: 34, height: 34)
                    .background(settingsTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micPauseGlass()
    }

    private func settingToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 20)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func statusRow(
        title: String,
        value: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer(minLength: 16)

            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var automationActions: some View {
        if #available(macOS 26.0, *) {
            automationActionContent
                .buttonStyle(.glass)
        } else {
            automationActionContent
                .buttonStyle(.bordered)
        }
    }

    private var automationActionContent: some View {
        HStack(spacing: 10) {
            Button(permissionButtonTitle) {
                performPermissionAction()
            }
            .disabled(model.isRequestingAutomationPermission)

            Button("Open Privacy Settings") {
                openAutomationPrivacySettings()
            }

            if model.isRequestingAutomationPermission {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var settingsTint: Color {
        model.settings.monitoringEnabled ? .mint : .secondary
    }

    private var microphoneStatusIcon: String {
        switch model.playbackCoordinator.state {
        case .disabled:
            "pause.circle.fill"
        case .micInactive:
            "checkmark.circle.fill"
        case .micActive:
            "mic.circle.fill"
        case .pausedByUtility:
            "pause.circle.fill"
        case .unavailable:
            "exclamationmark.triangle.fill"
        }
    }

    private var microphoneStatusTint: Color {
        switch model.playbackCoordinator.state {
        case .disabled:
            .secondary
        case .micInactive:
            .mint
        case .micActive:
            .orange
        case .pausedByUtility:
            .pink
        case .unavailable:
            .red
        }
    }

    private var automationStatusIcon: String {
        switch model.automationPermission {
        case .granted:
            "checkmark.circle.fill"
        case .denied, .unavailable:
            "exclamationmark.triangle.fill"
        case .notDetermined:
            "questionmark.circle.fill"
        }
    }

    private var automationStatusTint: Color {
        switch model.automationPermission {
        case .granted:
            .mint
        case .denied, .unavailable:
            .red
        case .notDetermined:
            .orange
        }
    }

    private var automationMessageIcon: String {
        switch model.automationPermission {
        case .denied, .unavailable:
            "exclamationmark.circle.fill"
        default:
            "checkmark.circle.fill"
        }
    }

    private var loginItemStatusIcon: String {
        model.loginItemManager.requiresApproval
            ? "exclamationmark.circle.fill"
            : "xmark.circle.fill"
    }

    private var permissionButtonTitle: String {
        switch model.automationPermission {
        case .notDetermined:
            "Request Permission"
        case .denied:
            "Open Automation Settings"
        case .granted:
            "Check Permission"
        case .unavailable:
            "Try Again"
        }
    }

    private var permissionMessageColor: Color {
        switch model.automationPermission {
        case .denied, .unavailable:
            .red
        default:
            .secondary
        }
    }

    private var loginItemMessageColor: Color {
        model.loginItemManager.requiresApproval ? .orange : .red
    }

    private func performPermissionAction() {
        if model.automationPermission == .denied {
            openAutomationPrivacySettings()
            return
        }

        Task {
            await model.requestAutomationPermission()
        }
    }

    private func openAutomationPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openLoginItemsSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
