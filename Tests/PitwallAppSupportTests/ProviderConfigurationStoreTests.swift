import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderConfigurationStoreTests: XCTestCase {
    func testDefaultSnapshotKeepsAllSupportedProvidersVisible() async {
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())

        let snapshot = await store.load()

        XCTAssertEqual(snapshot.providerProfiles.map(\.providerId), [.claude, .codex, .gemini])
        XCTAssertTrue(snapshot.providerProfiles.allSatisfy(\.isEnabled))
    }

    func testPersistsNonSecretProfilesAndPreferences() async throws {
        let defaults = isolatedDefaults()
        let store = ProviderConfigurationStore(userDefaults: defaults)
        let snapshot = ProviderConfigurationSnapshot(
            providerProfiles: [
                ProviderProfileConfiguration(
                    providerId: .claude,
                    accountLabel: "Work",
                    planProfile: "Max",
                    authMode: "manual",
                    telemetryEnabled: true,
                    accuracyModeEnabled: true,
                    lastConfidenceExplanation: "Exact telemetry"
                ),
                ProviderProfileConfiguration(providerId: .codex, isEnabled: false),
                ProviderProfileConfiguration(providerId: .gemini, isEnabled: true)
            ],
            claudeAccounts: [
                ClaudeAccountConfiguration(id: "acct_b", label: "B", organizationId: "org_b"),
                ClaudeAccountConfiguration(id: "acct_a", label: "A", organizationId: "org_a")
            ],
            selectedClaudeAccountId: "acct_a",
            userPreferences: UserPreferences(
                resetDisplayPreference: .resetTime,
                providerRotationMode: .pinned,
                pinnedProviderId: .gemini,
                rotationInterval: 9
            )
        )

        try await store.save(snapshot)
        let reloaded = await ProviderConfigurationStore(userDefaults: defaults).load()

        XCTAssertEqual(reloaded, snapshot)
    }

    func testClaudeCredentialSetupIsWriteOnlyAndUsesSecretStore() async throws {
        let secret = "sk-ant-sensitive-session"
        let secretStore = InMemorySecretStore()
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let settings = ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        )

        let state = try await settings.saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: secret
            )
        )
        let savedSecret = try await secretStore.loadSecret(
            for: ProviderSecretKey(
                providerId: .claude,
                accountId: "acct_1",
                purpose: ClaudeAccountSettings.sessionKeyPurpose
            )
        )

        XCTAssertEqual(savedSecret, secret)
        XCTAssertEqual(state.secretState.status, .configured)
        XCTAssertNil(state.renderedSessionKey)
        XCTAssertNil(state.secretState.renderedSecretValue)
        XCTAssertFalse(String(describing: state).contains(secret))
        XCTAssertFalse(String(describing: state.secretState).contains(secret))
    }

    func testMarkExpiredReportsExpiredWithoutRenderingSecret() async throws {
        let secretStore = InMemorySecretStore()
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let settings = ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        )

        _ = try await settings.saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: "session-secret"
            )
        )
        try await settings.markExpired(
            accountId: "acct_1",
            errorDescription: "Claude auth expired."
        )

        let state = try await settings.setupState(accountId: "acct_1")

        XCTAssertEqual(state?.secretState.status, .expired)
        XCTAssertEqual(state?.lastErrorDescription, "Claude auth expired.")
        XCTAssertNil(state?.renderedSessionKey)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PitwallAppSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
