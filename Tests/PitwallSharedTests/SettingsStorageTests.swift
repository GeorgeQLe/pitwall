import XCTest
import PitwallCore
@testable import PitwallShared

final class SettingsStorageTests: XCTestCase {
    func testLoadsDefaultPreferences() async {
        let storage = InMemorySettingsStorage()
        let preferences = await storage.loadPreferences()

        XCTAssertEqual(preferences.resetDisplayPreference, .countdown)
        XCTAssertEqual(preferences.providerRotationMode, .automatic)
        XCTAssertNil(preferences.pinnedProviderId)
        XCTAssertEqual(preferences.menuBarTitleMode, .compact)
    }

    func testRoundTripPersistsPreferences() async throws {
        let storage = InMemorySettingsStorage()
        let updated = UserPreferences(
            resetDisplayPreference: .resetTime,
            providerRotationMode: .pinned,
            pinnedProviderId: .codex,
            rotationInterval: 9,
            menuBarTheme: .f1Quali,
            menuBarTitleMode: .rich,
            notificationPreferences: NotificationPreferences(
                pacingThresholdNotificationsEnabled: true,
                pacingThreshold: .critical
            )
        )

        try await storage.savePreferences(updated)
        let reloaded = await storage.loadPreferences()

        XCTAssertEqual(reloaded, updated)
    }

    func testRotationIntervalIsClampedToSupportedRange() {
        let tooShort = UserPreferences(rotationInterval: 1)
        let tooLong = UserPreferences(rotationInterval: 60)
        XCTAssertEqual(tooShort.rotationInterval, 5)
        XCTAssertEqual(tooLong.rotationInterval, 10)
    }
}
