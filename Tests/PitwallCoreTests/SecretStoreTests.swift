import XCTest
@testable import PitwallCore

final class SecretStoreTests: XCTestCase {
    func testInjectedFakeStoreSavesLoadsAndDeletesProviderSecrets() async throws {
        let store = InMemorySecretStore()
        let key = ProviderSecretKey(
            providerId: .claude,
            accountId: "acct_123",
            purpose: "sessionKey"
        )

        try await store.save("sk-ant-session-secret", for: key)
        XCTAssertEqual(try await store.loadSecret(for: key), "sk-ant-session-secret")

        try await store.deleteSecret(for: key)
        XCTAssertNil(try await store.loadSecret(for: key))
    }

    func testPublicSecretStateIsWriteOnlyAndDoesNotRenderSavedValue() async throws {
        let store = InMemorySecretStore()
        let key = ProviderSecretKey(
            providerId: .claude,
            accountId: "acct_123",
            purpose: "sessionKey"
        )

        try await store.save("sk-ant-session-secret", for: key)

        let publicState = try await ProviderSecretState.makePublicState(
            providerId: .claude,
            accountId: "acct_123",
            purpose: "sessionKey",
            store: store
        )

        XCTAssertEqual(publicState.providerId, .claude)
        XCTAssertEqual(publicState.accountId, "acct_123")
        XCTAssertEqual(publicState.status, .configured)
        XCTAssertNil(publicState.renderedSecretValue)
        XCTAssertFalse(String(describing: publicState).contains("sk-ant-session-secret"))
    }

    func testMissingSecretStateCanBeRenderedWithoutASecretValue() async throws {
        let publicState = try await ProviderSecretState.makePublicState(
            providerId: .claude,
            accountId: "acct_123",
            purpose: "sessionKey",
            store: InMemorySecretStore()
        )

        XCTAssertEqual(publicState.status, .missing)
        XCTAssertNil(publicState.renderedSecretValue)
    }
}
