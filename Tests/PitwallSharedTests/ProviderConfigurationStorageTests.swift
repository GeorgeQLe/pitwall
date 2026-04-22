import XCTest
import PitwallCore
@testable import PitwallShared

final class ProviderConfigurationStorageTests: XCTestCase {
    func testDefaultSnapshotExposesAllSupportedProviders() async {
        let storage = InMemoryProviderConfigurationStorage()
        let snapshot = await storage.load()
        XCTAssertEqual(
            snapshot.providerProfiles.map(\.providerId),
            PitwallShared.supportedProviders
        )
        XCTAssertTrue(snapshot.claudeAccounts.isEmpty)
        XCTAssertNil(snapshot.selectedClaudeAccountId)
    }

    func testRoundTripSavesAndLoadsConfigurationSnapshot() async throws {
        let storage = InMemoryProviderConfigurationStorage()
        let account = ClaudeAccountConfiguration(
            id: "acct_1",
            label: "Primary",
            organizationId: "org_1",
            isEnabled: true
        )
        let updated = ProviderConfigurationSnapshot(
            providerProfiles: [ProviderProfileConfiguration(providerId: .claude)],
            claudeAccounts: [account],
            selectedClaudeAccountId: "acct_1",
            userPreferences: UserPreferences(resetDisplayPreference: .resetTime)
        )

        try await storage.save(updated)
        let reloaded = await storage.load()

        XCTAssertEqual(reloaded, updated)
    }
}
