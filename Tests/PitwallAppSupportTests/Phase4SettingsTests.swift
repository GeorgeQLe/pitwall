import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class Phase4SettingsTests: XCTestCase {
    func testPersistsHistoryDiagnosticsNotificationAndHeatmapPreferences() async throws {
        let defaults = isolatedDefaults()
        let store = Phase4SettingsStore(userDefaults: defaults)
        let settings = Phase4Settings(
            history: HistoryPreferences(isEnabled: true, retentionDays: 7),
            diagnostics: DiagnosticsPreferences(includeRecentEvents: true),
            notifications: NotificationPreferences(
                resetNotificationsEnabled: true,
                expiredAuthNotificationsEnabled: true,
                telemetryDegradedNotificationsEnabled: false,
                pacingThresholdNotificationsEnabled: true,
                pacingThreshold: .warning
            ),
            gitHubHeatmap: GitHubHeatmapSettings(
                isEnabled: true,
                username: "octocat",
                lastRefreshAt: Date(timeIntervalSince1970: 1_800_000_000),
                tokenState: .configured
            )
        )

        try await store.save(settings)
        let reloaded = await Phase4SettingsStore(userDefaults: defaults).load()

        XCTAssertEqual(reloaded, settings)
    }

    func testGitHubTokenIsStoredInSecretStoreNotUserDefaults() async throws {
        let token = "ghp_sensitive_token"
        let defaults = isolatedDefaults()
        let settingsStore = Phase4SettingsStore(userDefaults: defaults)
        let secretStore = InMemorySecretStore()
        let tokenManager = GitHubHeatmapTokenManager(secretStore: secretStore)

        let state = try await tokenManager.saveToken(token, username: "octocat")
        try await settingsStore.save(Phase4Settings(
            gitHubHeatmap: GitHubHeatmapSettings(
                isEnabled: true,
                username: "octocat",
                tokenState: state.status
            )
        ))

        let defaultsDescription = defaults.dictionaryRepresentation().description
        let savedSecret = try await secretStore.loadSecret(for: GitHubHeatmapTokenManager.secretKey(username: "octocat"))

        XCTAssertEqual(savedSecret, token)
        XCTAssertFalse(defaultsDescription.contains(token))
        XCTAssertNil(state.renderedToken)
        XCTAssertFalse(String(describing: state).contains(token))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PitwallPhase4SettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
