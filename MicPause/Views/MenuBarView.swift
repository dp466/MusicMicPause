import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button(model.settings.monitoringEnabled ? "Disable Monitoring" : "Enable Monitoring") {
            model.settings.monitoringEnabled.toggle()
        }

        Divider()

        Text(menuLine(prefix: "Mic: ", value: model.microphoneMonitor.deviceName))
        Text(menuLine(prefix: "Status: ", value: model.playbackCoordinator.state.label))

        Divider()

        Toggle(
            "Resume Automatically",
            isOn: Binding(
                get: { model.settings.automaticResume },
                set: { model.settings.automaticResume = $0 }
            )
        )

        Picker(
            "Resume Delay",
            selection: Binding(
                get: { model.settings.resumeDelay },
                set: { model.settings.resumeDelay = $0 }
            )
        ) {
            ForEach(ResumeDelay.allCases) { delay in
                Text(delay.title).tag(delay)
            }
        }

        Divider()

        SettingsLink {
            Text("Open Settings…")
        }
        .keyboardShortcut(",")

        Button("Quit Mic Pause") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func menuLine(prefix: String, value: String) -> String {
        let maximumLength = 30
        guard prefix.count + value.count > maximumLength else {
            return prefix + value
        }
        return prefix + String(value.prefix(maximumLength - prefix.count - 1)) + "…"
    }
}
