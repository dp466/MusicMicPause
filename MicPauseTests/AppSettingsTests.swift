import XCTest
import Observation
@testable import MicPause

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaults() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            XCTAssertTrue(settings.monitoringEnabled)
            XCTAssertTrue(settings.automaticResume)
            XCTAssertEqual(settings.resumeDelay, .twoSeconds)
        }
    }

    func testValuesPersist() {
        withDefaults { defaults in
            var settings: AppSettings? = AppSettings(defaults: defaults)
            settings?.monitoringEnabled = false
            settings?.automaticResume = false
            settings?.resumeDelay = .fiveSeconds
            settings = nil

            let restored = AppSettings(defaults: defaults)
            XCTAssertFalse(restored.monitoringEnabled)
            XCTAssertFalse(restored.automaticResume)
            XCTAssertEqual(restored.resumeDelay, .fiveSeconds)
        }
    }

    func testInvalidDelayFallsBackToTwoSeconds() {
        withDefaults { defaults in
            defaults.set(123.0, forKey: "resumeDelay")

            let settings = AppSettings(defaults: defaults)

            XCTAssertEqual(settings.resumeDelay, .twoSeconds)
        }
    }

    func testChangesNotifyObservers() async {
        let suiteName = "MicPauseTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let notified = expectation(description: "resume-delay observation fired")

        withObservationTracking {
            _ = settings.resumeDelay
        } onChange: {
            notified.fulfill()
        }

        settings.resumeDelay = .fiveSeconds

        await fulfillment(of: [notified], timeout: 1)
    }

    func testBackgroundListenersAreIgnoredButSpeechAndAppsAreNot() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            XCTAssertTrue(settings.ignoreAlwaysOnSystemListeners)

            // Sound Recognition holds the microphone open indefinitely.
            XCTAssertTrue(settings.ignores(source("com.apple.soundanalysisd", .systemListener)))
            // Dictation and Siri only capture when actually invoked.
            XCTAssertFalse(settings.ignores(source("com.apple.CoreSpeech", .speechService)))
            // A conference call must always pause playback.
            XCTAssertFalse(settings.ignores(source("us.zoom.xos", .application)))
        }
    }

    func testTurningOffTheToggleLetsBackgroundListenersPause() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.ignoreAlwaysOnSystemListeners = false

            XCTAssertFalse(settings.ignores(source("com.apple.soundanalysisd", .systemListener)))
        }
    }

    func testIgnoredAppsPersistAndOverrideKind() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let zoom = source("us.zoom.xos", .application)

            settings.ignore(zoom)
            XCTAssertTrue(settings.ignores(zoom))

            // Adding the same app twice must not duplicate the row.
            settings.ignore(zoom)
            XCTAssertEqual(settings.ignoredCaptureIdentifiers, ["us.zoom.xos"])

            XCTAssertEqual(
                AppSettings(defaults: defaults).ignoredCaptureIdentifiers,
                ["us.zoom.xos"]
            )

            settings.stopIgnoring(zoom.identifier)
            XCTAssertFalse(settings.ignores(zoom))
            XCTAssertTrue(AppSettings(defaults: defaults).ignoredCaptureIdentifiers.isEmpty)
        }
    }

    func testUnregisteredCaptureHelpersAreNotAutomaticallyIgnored() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            for identifier in ["com.example.DictationHelper", "com.apple.WebKit.GPU", "unknown-recorder"] {
                let kind = AudioCaptureInspector.kind(for: identifier)
                XCTAssertEqual(kind, .application)
                XCTAssertFalse(settings.ignores(source(identifier, kind)))
                settings.ignore(source(identifier, kind))
                XCTAssertTrue(settings.ignores(source(identifier, kind)))
            }
        }
    }

    func testOnlyKnownBackgroundListenersAreClassifiedAsListeners() {
        XCTAssertEqual(AudioCaptureInspector.kind(for: "com.apple.soundanalysisd"), .systemListener)
        XCTAssertEqual(AudioCaptureInspector.kind(for: "universalaccessd"), .systemListener)
        XCTAssertEqual(AudioCaptureInspector.kind(for: "com.apple.CoreSpeech"), .speechService)
        XCTAssertEqual(AudioCaptureInspector.kind(for: "corespeechd"), .speechService)
    }

    private func source(_ identifier: String, _ kind: CaptureSource.Kind) -> CaptureSource {
        CaptureSource(identifier: identifier, name: identifier, kind: kind)
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "MicPauseTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
