import Foundation
import XCTest
import PitwallCore
@testable import PitwallLinux

final class LinuxClaudeCredentialFlowTests: XCTestCase {
    func test_save_storesSessionKeyAndReportsConfigured() async throws {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        let flow = LinuxClaudeCredentialFlow(secretStore: store)

        let state = try await flow.save(
            LinuxClaudeCredentialInput(
                accountId: "acct-1",
                accountLabel: "Primary",
                organizationId: "org-1",
                sessionKey: "sk-value",
                lastActiveOrg: "org-1"
            )
        )

        XCTAssertEqual(state.status, .configured)

        let sessionKey = ProviderSecretKey(
            providerId: .claude,
            accountId: "acct-1",
            purpose: "sessionKey"
        )
        let lastActive = ProviderSecretKey(
            providerId: .claude,
            accountId: "acct-1",
            purpose: "lastActiveOrg"
        )
        let storedSession = try await store.loadSecret(for: sessionKey)
        let storedLast = try await store.loadSecret(for: lastActive)
        XCTAssertEqual(storedSession, "sk-value")
        XCTAssertEqual(storedLast, "org-1")
    }

    func test_save_requiresSessionKey() async {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        let flow = LinuxClaudeCredentialFlow(secretStore: store)

        do {
            _ = try await flow.save(
                LinuxClaudeCredentialInput(
                    accountId: "acct-1",
                    accountLabel: "Primary",
                    organizationId: "org-1",
                    sessionKey: ""
                )
            )
            XCTFail("Expected missingSessionKey")
        } catch let error as LinuxClaudeCredentialError {
            XCTAssertEqual(error, .missingSessionKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_secretStateDoesNotExposeSessionKeyValue() async throws {
        let store = LinuxSecretServiceStore(backend: InMemoryLinuxSecretBackend())
        let flow = LinuxClaudeCredentialFlow(secretStore: store)

        let state = try await flow.save(
            LinuxClaudeCredentialInput(
                accountId: "acct-1",
                accountLabel: "Primary",
                organizationId: "org-1",
                sessionKey: "sk-do-not-render"
            )
        )

        XCTAssertNil(state.renderedSecretValue)
        XCTAssertFalse(state.description.contains("sk-do-not-render"))
    }
}
