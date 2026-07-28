import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPrivacyPolicy = false

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Enable monitoring",
                    isOn: Binding(
                        get: { model.settings.monitoringEnabled },
                        set: { model.settings.monitoringEnabled = $0 }
                    )
                )

                Toggle(
                    "Launch Mic Pause at login",
                    isOn: Binding(
                        get: { model.loginItemManager.isEnabled },
                        set: { model.loginItemManager.setEnabled($0) }
                    )
                )

                if let statusMessage = model.loginItemManager.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(loginItemMessageColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if model.loginItemManager.requiresApproval {
                        Button("Open Login Items Settings") {
                            openLoginItemsSettings()
                        }
                    }
                }
            }

            Section("Playback") {
                Toggle(
                    "Resume Apple Music automatically",
                    isOn: Binding(
                        get: { model.settings.automaticResume },
                        set: { model.settings.automaticResume = $0 }
                    )
                )

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
            }

            Section("Microphone Activity") {
                LabeledContent("Selected microphone", value: model.microphoneMonitor.deviceName)
                LabeledContent("Status", value: model.playbackCoordinator.state.label)

                Text("Mic Pause detects only whether the selected microphone device is active. It does not record, access, or transmit audio.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Apple Music Automation") {
                LabeledContent("Permission", value: model.automationPermission.label)

                HStack {
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

                if let message = model.automationPermissionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(permissionMessageColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("macOS asks for Automation access the first time Mic Pause needs to control Apple Music. No Accessibility permission is used.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("About") {
                LabeledContent("Version", value: versionDescription)

                Button("Privacy Policy…") {
                    showingPrivacyPolicy = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding(.vertical, 8)
        .task {
            model.loginItemManager.refresh()
            await model.refreshAutomationPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await model.refreshAutomationPermission()
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
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
        model.loginItemManager.requiresApproval ? .secondary : .red
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
