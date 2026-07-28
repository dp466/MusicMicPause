import XCTest
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
