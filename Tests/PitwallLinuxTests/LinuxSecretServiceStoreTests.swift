import Foundation
import XCTest
import PitwallCore
@testable import PitwallLinux

final class LinuxSecretServiceStoreTests: XCTestCase {
    private let key = ProviderSecretKey(
        providerId: .claude,
        accountId: "acct-1",
        purpose: "sessionKey"
    )

    func test_save_thenLoad_returnsStoredSecret() async throws {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())

        try await store.save("secret-value", for: key)
        let loaded = try await store.loadSecret(for: key)

        XCTAssertEqual(loaded, "secret-value")
    }

    func test_loadSecret_returnsNilWhenNotConfigured() async throws {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        let loaded = try await store.loadSecret(for: key)
        XCTAssertNil(loaded)
    }

    func test_delete_removesSecret() async throws {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())

        try await store.save("secret", for: key)
        try await store.deleteSecret(for: key)
        let loaded = try await store.loadSecret(for: key)

        XCTAssertNil(loaded)
    }

    func test_save_failsClosedWhenBackendUnavailable() async {
        let store = LinuxSecretServiceStore(
            backend: InMemoryLinuxSecretBackend(writesEnabled: false)
        )

        do {
            try await store.save("secret", for: key)
            XCTFail("Expected save to throw when backend unavailable")
        } catch let error as LinuxSecretServiceError {
            XCTAssertEqual(error, .backendUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_loadSecret_returnsNilWhenBackendUnavailable_neverDegradedDefault() async throws {
        let store = LinuxSecretServiceStore(
            backend: InMemoryLinuxSecretBackend(writesEnabled: false)
        )

        let loaded = try await store.loadSecret(for: key)

        XCTAssertNil(loaded)
    }

    func test_attributes_includeSchemaAndKeyComponents() {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        let attrs = store.attributes(for: key)
        XCTAssertEqual(attrs["provider"], "claude")
        XCTAssertEqual(attrs["account"], "acct-1")
        XCTAssertEqual(attrs["purpose"], "sessionKey")
        XCTAssertEqual(attrs["schema"], "com.pitwall.Credential")
    }

    func test_label_formatsProviderAccountPurpose() {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        XCTAssertEqual(store.label(for: key), "Pitwall: claude / acct-1 / sessionKey")
    }
}
