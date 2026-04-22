import Foundation
import XCTest
import PitwallCore
@testable import PitwallWindows

final class WindowsClaudeCredentialFlowTests: XCTestCase {
    func test_save_storesSessionKeyAndReportsConfigured() async throws {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())
        let flow = WindowsClaudeCredentialFlow(secretStore: store)

        let state = try await flow.save(
            WindowsClaudeCredentialInput(
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
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())
        let flow = WindowsClaudeCredentialFlow(secretStore: store)

        do {
            _ = try await flow.save(
                WindowsClaudeCredentialInput(
                    accountId: "acct-1",
                    accountLabel: "Primary",
                    organizationId: "org-1",
                    sessionKey: ""
                )
            )
            XCTFail("Expected missingSessionKey")
        } catch let error as WindowsClaudeCredentialError {
            XCTAssertEqual(error, .missingSessionKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_secretStateDoesNotExposeSessionKeyValue() async throws {
        let store = WindowsCredentialManagerSecretStore(backend: InMemoryWindowsCredentialBackend())
        let flow = WindowsClaudeCredentialFlow(secretStore: store)

        let state = try await flow.save(
            WindowsClaudeCredentialInput(
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
