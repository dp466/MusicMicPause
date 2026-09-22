import AppKit
import SwiftUI

struct SettingsView: View {
    let model: AppModel
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
            await model.refreshVisibleState()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.14)) {
                hasAppeared = true
            }
        }
        // Re-showing the window does not re-run `task`; the window controller
        // refreshes the model when it brings the window forward.
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(settingsTint.opacity(0.14))

                MicPauseBrandMark(tint: settingsTint)
                    .padding(9)
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
                model.monitoringEnabled ? "Monitoring" : "Paused",
                systemImage: model.monitoringEnabled ? "waveform" : "pause.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(settingsTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(settingsTint.opacity(0.11), in: Capsule())
            .accessibilityLabel(
                model.monitoringEnabled
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
            meetingAssistCard
            phoneCallsCard
            microphoneCard
            captureSourcesCard
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
                    get: { model.monitoringEnabled },
                    set: { model.setMonitoringEnabled($0) }
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

            Divider()

            settingToggle(
                title: "Play feedback sounds",
                detail: "Quiet tones confirm Music and meeting-microphone changes. An unmute tone may be heard by meeting participants.",
                isOn: Binding(
                    get: { model.settings.feedbackSoundsEnabled },
                    set: { model.settings.feedbackSoundsEnabled = $0 }
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
                Text("MUSIC & MEETING RECOVERY DELAY")
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
                .disabled(
                    !model.settings.automaticResume && !model.settings.meetingAssistEnabled
                )

                Text("Meeting Assist waits this long before unmuting and restoring sound. It still applies when automatic Music resume is off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var meetingAssistCard: some View {
        settingsCard(
            icon: "person.wave.2.fill",
            title: "Meeting Assist",
            subtitle: "Make room for ChatGPT, Dictation, and MacWhisper"
        ) {
            settingToggle(
                title: "Enable Meeting Assist",
                detail: "While a supported meeting and dictation are using the microphone together, lower the sound and protect your spoken prompt.",
                isOn: Binding(
                    get: { model.settings.meetingAssistEnabled },
                    set: { model.settings.meetingAssistEnabled = $0 }
                )
            )

            Divider()

            settingToggle(
                title: "Lower meeting sound",
                detail: "Temporarily lowers the current system output, then restores only the volume Mic Pause changed.",
                isOn: Binding(
                    get: { model.settings.lowerMeetingAudio },
                    set: { model.settings.lowerMeetingAudio = $0 }
                )
            )
            .disabled(!model.settings.meetingAssistEnabled)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("REDUCED VOLUME")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Spacer()
                    Text("\(Int(model.settings.reducedMeetingVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { model.settings.reducedMeetingVolume },
                        set: { model.settings.reducedMeetingVolume = $0 }
                    ),
                    in: 0.05...0.60,
                    step: 0.05
                )
                .accessibilityLabel("Reduced meeting volume")
            }
            .disabled(
                !model.settings.meetingAssistEnabled || !model.settings.lowerMeetingAudio
            )

            Divider()

            settingToggle(
                title: "Mute the meeting microphone",
                detail: "Mutes promptly when dictation begins. After dictation ends, it waits for the recovery delay before unmuting a meeting that Mic Pause muted.",
                isOn: Binding(
                    get: { model.settings.muteMeetingMicrophone },
                    set: { model.settings.muteMeetingMicrophone = $0 }
                )
            )
            .disabled(!model.settings.meetingAssistEnabled)

            Divider()

            statusRow(
                title: "Meeting Assist status",
                value: model.meetingAssistCoordinator.state.label,
                icon: meetingAssistStatusIcon,
                tint: meetingAssistStatusTint
            )

            statusRow(
                title: "Accessibility",
                value: model.accessibilityAutomation.permissionStatus.label,
                icon: model.accessibilityAutomation.permissionStatus == .granted
                    ? "checkmark.shield.fill"
                    : "lock.trianglebadge.exclamationmark.fill",
                tint: model.accessibilityAutomation.permissionStatus == .granted
                    ? .mint
                    : .orange
            )

            accessibilityActions

            Text("Supported meeting controls: Microsoft Teams, Zoom, FaceTime, and Phone. Browser meetings cannot be identified safely when the browser is also being used for other audio.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var phoneCallsCard: some View {
        settingsCard(
            icon: "iphone.and.arrow.forward",
            title: "Phone & Continuity Calls",
            subtitle: "Best-effort detection for relayed iPhone calls"
        ) {
            settingToggle(
                title: "Detect active Phone calls",
                detail: "Uses the enabled Hang Up control exposed by Phone or FaceTime. Merely opening either app never counts as a call.",
                isOn: Binding(
                    get: { model.settings.detectPhoneCalls },
                    set: { model.settings.detectPhoneCalls = $0 }
                )
            )

            Divider()

            statusRow(
                title: "Call detection",
                value: model.phoneCallMonitor.state.label,
                icon: phoneCallStatusIcon,
                tint: phoneCallStatusTint
            )

            Text("Apple does not expose its system call observer to native macOS apps, and relayed call audio may bypass public Core Audio and system-capture paths. This Accessibility fallback depends on macOS continuing to expose an enabled call control.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var captureSourcesCard: some View {
        settingsCard(
            icon: "waveform.badge.exclamationmark",
            title: "Microphone Sources",
            subtitle: "Choose which apps should pause playback"
        ) {
            settingToggle(
                title: "Ignore background listeners",
                detail: "Skips always-on system listeners such as Sound Recognition and Voice Control. Dictation and Siri still pause playback.",
                isOn: Binding(
                    get: { model.settings.ignoreAlwaysOnSystemListeners },
                    set: { model.setIgnoreAlwaysOnSystemListeners($0) }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("USING THE MICROPHONE NOW")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                if model.microphoneMonitor.captureSources.isEmpty {
                    Text("Nothing is using the microphone.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.microphoneMonitor.captureSources) { source in
                        captureSourceRow(source)
                    }
                }
            }

            if !model.settings.ignoredCaptureIdentifiers.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("IGNORED APPS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    ForEach(model.settings.ignoredCaptureIdentifiers, id: \.self) { identifier in
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            Text(identifier)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 12)

                            Button("Stop Ignoring") {
                                model.stopIgnoringCaptureSource(identifier)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func captureSourceRow(_ source: CaptureSource) -> some View {
        let isIgnored = model.settings.ignores(source)

        return HStack(spacing: 12) {
            Image(systemName: captureSourceIcon(source))
                .font(.system(size: 12))
                .foregroundStyle(isIgnored ? Color.secondary : settingsTint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(source.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(captureSourceCaption(source))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if isIgnored {
                Text("Ignored")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Ignore") {
                    model.ignoreCaptureSource(source)
                }
                .controlSize(.small)
            }
        }
    }

    private func captureSourceCaption(_ source: CaptureSource) -> String {
        switch source.kind {
        case .application:
            "App"
        case .speechService:
            "Dictation and Siri — pauses playback unless you ignore it"
        case .systemListener:
            model.settings.ignoreAlwaysOnSystemListeners
                ? "Background listener — ignored"
                : "Background listener"
        }
    }

    private func captureSourceIcon(_ source: CaptureSource) -> String {
        switch source.kind {
        case .application:
            "app.badge"
        case .speechService:
            "waveform"
        case .systemListener:
            "gearshape.fill"
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
                icon: model.automationPermission.symbol,
                tint: model.automationPermission.tint
            )

            Divider()

            automationActions

            if let message = model.automationPermissionMessage {
                Label(message, systemImage: automationMessageIcon)
                    .font(.caption)
                    .foregroundStyle(permissionMessageColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("macOS asks for Automation access the first time Mic Pause controls Apple Music. Accessibility is separate and is used only for enabled Meeting Assist and Phone-call detection.")
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

    @ViewBuilder
    private var accessibilityActions: some View {
        let content = HStack(spacing: 10) {
            Button(
                model.accessibilityAutomation.permissionStatus == .granted
                    ? "Check Permission"
                    : "Request Permission"
            ) {
                if model.accessibilityAutomation.permissionStatus == .granted {
                    model.refreshAccessibilityPermission()
                } else {
                    model.requestAccessibilityPermission()
                }
            }

            Button("Open Accessibility Settings") {
                openAccessibilityPrivacySettings()
            }
        }

        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }

    private var settingsTint: Color {
        model.monitoringEnabled ? .mint : .secondary
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

    private var meetingAssistStatusIcon: String {
        switch model.meetingAssistCoordinator.state {
        case .disabled:
            "pause.circle.fill"
        case .ready:
            "checkmark.circle.fill"
        case .active:
            "waveform.circle.fill"
        case .attention:
            "exclamationmark.triangle.fill"
        }
    }

    private var meetingAssistStatusTint: Color {
        switch model.meetingAssistCoordinator.state {
        case .disabled:
            .secondary
        case .ready:
            .mint
        case .active:
            .indigo
        case .attention:
            .orange
        }
    }

    private var phoneCallStatusIcon: String {
        switch model.phoneCallMonitor.state {
        case .disabled:
            "pause.circle.fill"
        case .permissionRequired, .unavailable:
            "exclamationmark.triangle.fill"
        case .idle:
            "phone.circle.fill"
        case .active:
            "phone.connection.fill"
        }
    }

    private var phoneCallStatusTint: Color {
        switch model.phoneCallMonitor.state {
        case .disabled:
            .secondary
        case .permissionRequired, .unavailable:
            .orange
        case .idle:
            .mint
        case .active:
            .green
        }
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

    private func openAccessibilityPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
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
