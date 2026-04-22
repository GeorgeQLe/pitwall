import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallLinux

final class LinuxSettingsStoreTests: XCTestCase {
    private var directory: URL!
    private var root: LinuxStorageRoot!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        root = LinuxStorageRoot(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_loadPreferences_returnsDefaultsWhenMissing() async {
        let store = LinuxSettingsStore(root: root)
        let prefs = await store.loadPreferences()
        XCTAssertEqual(prefs, UserPreferences())
    }

    func test_savePreferences_roundTripsValues() async throws {
        let store = LinuxSettingsStore(root: root)
        var prefs = UserPreferences()
        prefs.providerRotationMode = .pinned
        prefs.pinnedProviderId = .claude
        prefs.resetDisplayPreference = .resetTime
        prefs.notificationPreferences = NotificationPreferences(
            resetNotificationsEnabled: false,
            expiredAuthNotificationsEnabled: true,
            telemetryDegradedNotificationsEnabled: false,
            pacingThresholdNotificationsEnabled: true,
            pacingThreshold: .critical
        )

        try await store.savePreferences(prefs)
        let loaded = await store.loadPreferences()

        XCTAssertEqual(loaded.providerRotationMode, .pinned)
        XCTAssertEqual(loaded.pinnedProviderId, .claude)
        XCTAssertEqual(loaded.resetDisplayPreference, .resetTime)
        XCTAssertEqual(loaded.notificationPreferences.pacingThreshold, .critical)
        XCTAssertFalse(loaded.notificationPreferences.resetNotificationsEnabled)
    }
}
