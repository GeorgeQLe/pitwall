import Foundation
import XCTest
import PitwallCore
@testable import PitwallWindows

final class WindowsCredentialManagerSecretStoreTests: XCTestCase {
    private let key = ProviderSecretKey(
        providerId: .claude,
        accountId: "acct-1",
        purpose: "sessionKey"
    )

    func test_save_thenLoad_returnsStoredSecret() async throws {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())

        try await store.save("secret-value", for: key)
        let loaded = try await store.loadSecret(for: key)

        XCTAssertEqual(loaded, "secret-value")
    }

    func test_loadSecret_returnsNilWhenNotConfigured() async throws {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())
        let loaded = try await store.loadSecret(for: key)
        XCTAssertNil(loaded)
    }

    func test_delete_removesSecret() async throws {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())

        try await store.save("secret", for: key)
        try await store.deleteSecret(for: key)
        let loaded = try await store.loadSecret(for: key)

        XCTAssertNil(loaded)
    }

    func test_save_failsClosedWhenBackendUnavailable() async {
        let store = WindowsCredentialManagerSecretStore(
            backend: InMemoryWindowsCredentialBackend(writesEnabled: false)
        )

        do {
            try await store.save("secret", for: key)
            XCTFail("Expected save to throw when backend unavailable")
        } catch let error as WindowsCredentialManagerError {
            XCTAssertEqual(error, .backendUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_targetName_includesPrefixAndKeyComponents() {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())
        let name = store.targetName(for: key)
        XCTAssertEqual(name, "Pitwall:claude:acct-1:sessionKey")
    }
}
