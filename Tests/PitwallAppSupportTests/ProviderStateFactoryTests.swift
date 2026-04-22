import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderStateFactoryTests: XCTestCase {
    private let factory = ProviderStateFactory()

    func testProvidersKeepAllSupportedProvidersVisible() {
        let snapshot = ProviderConfigurationSnapshot(
            providerProfiles: [
                ProviderProfileConfiguration(providerId: .claude, planProfile: "Max"),
                ProviderProfileConfiguration(providerId: .codex, isEnabled: false, planProfile: "Plus"),
                ProviderProfileConfiguration(providerId: .gemini, authMode: "OAuth")
            ]
        )

        let providers = factory.providers(
            from: snapshot,
            claudeAccounts: [],
            existingProviders: []
        )

        XCTAssertEqual(providers.map(\.providerId), [.claude, .codex, .gemini])
        XCTAssertEqual(providers.first { $0.providerId == .claude }?.headline, "Claude credentials missing")
        XCTAssertEqual(providers.first { $0.providerId == .codex }?.headline, "Codex skipped")
        XCTAssertEqual(providers.first { $0.providerId == .codex }?.actions.map(\.title), ["Enable", "Settings"])
        XCTAssertEqual(providers.first { $0.providerId == .gemini }?.secondaryValue, "OAuth")
    }

    func testExistingPassiveProviderStatesSurviveConfigurationReload() {
        let codex = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .highConfidence,
            headline: "Detected from local metadata",
            primaryValue: "High confidence",
            secondaryValue: "Passive scan",
            confidenceExplanation: "Sanitized local metadata only."
        )

        let providers = factory.providers(
            from: ProviderConfigurationSnapshot(),
            claudeAccounts: [],
            existingProviders: [codex]
        )

        XCTAssertEqual(providers.first { $0.providerId == .codex }, codex)
        XCTAssertEqual(providers.map(\.providerId), [.claude, .codex, .gemini])
    }

    func testClaudeConfiguredStateDoesNotExposeSavedSecret() {
        let account = ClaudeAccountSetupState(
            accountId: "acct_1",
            label: "Work",
            organizationId: "org_1",
            secretState: ProviderSecretState(
                providerId: .claude,
                accountId: "acct_1",
                purpose: ClaudeAccountSettings.sessionKeyPurpose,
                status: .configured
            ),
            isEnabled: true,
            lastSuccessfulRefreshAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastErrorDescription: nil
        )

        let claude = factory.providers(
            from: ProviderConfigurationSnapshot(),
            claudeAccounts: [account],
            existingProviders: []
        )
        .first { $0.providerId == .claude }

        XCTAssertEqual(claude?.status, .configured)
        XCTAssertEqual(claude?.confidence, .providerSupplied)
        XCTAssertEqual(claude?.primaryValue, "Work")
        XCTAssertEqual(claude?.secondaryValue, "org_1")
        XCTAssertEqual(claude?.actions.first { $0.kind == .refresh }?.isEnabled, true)
        XCTAssertFalse(String(describing: claude).contains("sessionKey"))
        XCTAssertTrue(claude?.confidenceExplanation.contains("never rendered") == true)
    }

    func testClaudeExpiredStateKeepsRefreshDisabledAndExplainsReplacement() {
        let account = ClaudeAccountSetupState(
            accountId: "acct_1",
            label: "Work",
            organizationId: "org_1",
            secretState: ProviderSecretState(
                providerId: .claude,
                accountId: "acct_1",
                purpose: ClaudeAccountSettings.sessionKeyPurpose,
                status: .expired
            ),
            isEnabled: true,
            lastSuccessfulRefreshAt: nil,
            lastErrorDescription: "Claude auth expired."
        )

        let claude = factory.providers(
            from: ProviderConfigurationSnapshot(),
            claudeAccounts: [account],
            existingProviders: []
        )
        .first { $0.providerId == .claude }

        XCTAssertEqual(claude?.status, .expired)
        XCTAssertEqual(claude?.confidence, .observedOnly)
        XCTAssertEqual(claude?.headline, "Claude auth expired.")
        XCTAssertEqual(claude?.actions.first { $0.kind == .refresh }?.isEnabled, false)
    }

    func testInitialAppStateUsesSanitizedPlaceholderState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = factory.initialAppState(now: now)

        XCTAssertEqual(state.selectedProviderId, .claude)
        XCTAssertEqual(state.orderedProviders.map(\.providerId), [.claude, .codex, .gemini])
        XCTAssertEqual(state.provider(for: .claude)?.confidence, .exact)
        XCTAssertTrue(state.provider(for: .codex)?.confidenceExplanation.contains("Prompt text") == true)
        XCTAssertEqual(state.provider(for: .gemini)?.status, .missingConfiguration)
    }
}
