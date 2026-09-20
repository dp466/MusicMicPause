import Foundation
import ServiceManagement
import XCTest
@testable import MicPause

@MainActor
final class LoginItemManagerTests: XCTestCase {
    func testFirstLaunchRegistersMainApp() {
        withHarness(status: .notRegistered) { service, defaults in
            let manager = LoginItemManager(
                service: service,
                defaults: defaults,
                bundleURL: URL(fileURLWithPath: "/Applications/MicPause.app"),
                enableOnFirstLaunch: true
            )

            XCTAssertEqual(service.registerCallCount, 1)
            XCTAssertTrue(manager.isEnabled)
        }
    }

    func testLaterLaunchRespectsDisabledChoice() {
        withHarness(status: .notRegistered) { service, defaults in
            defaults.set(true, forKey: "didConfigureLaunchAtLogin")

            let manager = LoginItemManager(
                service: service,
                defaults: defaults,
                bundleURL: URL(fileURLWithPath: "/Applications/MicPause.app"),
                enableOnFirstLaunch: true
            )

            XCTAssertEqual(service.registerCallCount, 0)
            XCTAssertFalse(manager.isEnabled)
        }
    }

    func testTurningLoginItemOffPersistsChoice() {
        withHarness(status: .enabled) { service, defaults in
            defaults.set(true, forKey: "didConfigureLaunchAtLogin")
            defaults.set(
                Bundle.main.bundleURL.standardizedFileURL.path,
                forKey: "registeredLoginItemBundlePath"
            )
            let manager = LoginItemManager(
                service: service,
                defaults: defaults,
                enableOnFirstLaunch: false
            )

            manager.setEnabled(false)

            XCTAssertEqual(service.unregisterCallCount, 1)
            XCTAssertFalse(manager.isEnabled)
            XCTAssertTrue(defaults.bool(forKey: "didConfigureLaunchAtLogin"))
        }
    }

    func testApprovalStateIsShown() {
        withHarness(status: .requiresApproval) { service, defaults in
            defaults.set(true, forKey: "didConfigureLaunchAtLogin")
            defaults.set(
                Bundle.main.bundleURL.standardizedFileURL.path,
                forKey: "registeredLoginItemBundlePath"
            )
            let manager = LoginItemManager(
                service: service,
                defaults: defaults,
                enableOnFirstLaunch: false
            )

            XCTAssertFalse(manager.isEnabled)
            XCTAssertTrue(manager.requiresApproval)
            XCTAssertNotNil(manager.statusMessage)
        }
    }

    func testEnabledRegistrationIsRepairedAfterAppMoves() {
        withHarness(status: .enabled) { service, defaults in
            defaults.set(true, forKey: "didConfigureLaunchAtLogin")
            defaults.set(
                "/private/tmp/DerivedData/MicPause.app",
                forKey: "registeredLoginItemBundlePath"
            )

            let manager = LoginItemManager(
                service: service,
                defaults: defaults,
                bundleURL: URL(fileURLWithPath: "/Applications/MicPause.app"),
                enableOnFirstLaunch: true
            )

            XCTAssertTrue(manager.isEnabled)
            XCTAssertEqual(service.unregisterCallCount, 1)
            XCTAssertEqual(service.registerCallCount, 1)
            XCTAssertEqual(
                defaults.string(forKey: "registeredLoginItemBundlePath"),
                "/Applications/MicPause.app"
            )
        }
    }

    private func withHarness(
        status: SMAppService.Status,
        _ body: (FakeLoginItemService, UserDefaults) -> Void
    ) {
        let suiteName = "MicPauseTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        body(FakeLoginItemService(status: status), defaults)
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemServicing {
    var status: SMAppService.Status
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }
}
