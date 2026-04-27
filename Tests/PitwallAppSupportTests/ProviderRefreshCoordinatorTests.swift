import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderRefreshCoordinatorTests: XCTestCase {
    func testMissingClaudeCredentialsDoNotCallClientAndKeepPassiveProvidersVisible() async {
        let client = FakeClaudeUsageClient()
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: client,
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "auth.json": ""]
                ),
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: ["settings.json": #"{"selectedAuthType":"oauth-personal"}"#]
                )
            ),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let requestedSessionKeys = await client.sessionKeys()

        XCTAssertEqual(requestedSessionKeys, [])
        XCTAssertEqual(outcome.appState.provider(for: .claude)?.status, .missingConfiguration)
        XCTAssertEqual(outcome.appState.provider(for: .codex)?.status, .configured)
        XCTAssertEqual(outcome.appState.provider(for: .gemini)?.status, .configured)
    }

    func testCodexWithoutAuthRemainsUnconfigured() async {
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "history.jsonl": ""]
                ),
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: ["settings.json": #"{"selectedAuthType":"oauth-personal"}"#]
                )
            ),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = outcome.appState.provider(for: .codex)

        XCTAssertEqual(codex?.status, .missingConfiguration)
        XCTAssertEqual(codex?.headline, "Codex login not detected")
        XCTAssertEqual(codex?.secondaryValue, "CLI auth not detected")
    }

    func testCodexCLIStatusOverridesPassiveMissingAuth() async {
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "history.jsonl": ""]
                )
            ),
            codexAuthStatusProvider: FakeCodexStatusProvider(
                state: CodexSetupState(
                    status: .configured,
                    authMode: .chatgpt,
                    headline: "Connected with ChatGPT",
                    detail: "Logged in using ChatGPT"
                )
            ),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = outcome.appState.provider(for: .codex)

        XCTAssertEqual(codex?.status, .configured)
        XCTAssertEqual(codex?.headline, "Connected with ChatGPT")
        XCTAssertEqual(codex?.secondaryValue, "ChatGPT")
        XCTAssertTrue(codex?.confidenceExplanation.contains("Login verified through the Codex CLI.") == true)
    }

    func testManualRefreshLoadsClaudeSecretAndDoesNotUseLiveSources() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let secretStore = InMemorySecretStore()
        let client = FakeClaudeUsageClient()
        let expectedState = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            lastUpdatedAt: now,
            confidenceExplanation: "Fresh exact usage."
        )
        await client.enqueue(.success(ClaudeUsageClientResult(
            response: ClaudeUsageResponse(sections: []),
            providerState: expectedState,
            snapshot: ClaudeUsageSnapshot(
                recordedAt: now,
                weeklyUtilizationPercent: 35,
                weeklyResetAt: now.addingTimeInterval(24 * 60 * 60)
            )
        )))

        _ = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: "stored-session-key"
            )
        )
        let loader = FakeSnapshotLoader(
            codexSnapshot: LocalProviderFileSnapshot(
                homePath: "/codex",
                files: ["config.toml": "", "auth.json": "", "history.jsonl": ""]
            ),
            geminiSnapshot: LocalProviderFileSnapshot(
                homePath: "/gemini",
                files: [
                    "settings.json": #"{"profile":"pro"}"#,
                    "oauth_creds.json": "",
                    "tmp/run/chats/session-1.json": #"{"tokenCount":12}"#
                ]
            )
        )
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: secretStore,
            claudeClient: client,
            snapshotLoader: loader,
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let requestedSessionKeys = await client.sessionKeys()
        let requestedAccountIds = await client.accountIds()

        XCTAssertEqual(requestedSessionKeys, ["stored-session-key"])
        XCTAssertEqual(requestedAccountIds, ["acct_1"])
        XCTAssertEqual(loader.codexLoadCount, 1)
        XCTAssertEqual(loader.geminiLoadCount, 1)
        XCTAssertEqual(outcome.appState.provider(for: .claude), expectedState)
        XCTAssertEqual(outcome.appState.provider(for: .codex)?.payloads.first?.values["activityDetected"], "true")
        XCTAssertEqual(outcome.appState.provider(for: .gemini)?.payloads.first?.values["tokenCountObserved"], "12")
    }

    func testReplacementClaudeSessionKeyRotatesThroughSecretStoreOnly() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let secretStore = InMemorySecretStore()
        let client = FakeClaudeUsageClient()
        await client.enqueue(.success(ClaudeUsageClientResult(
            response: ClaudeUsageResponse(sections: []),
            providerState: ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .configured,
                confidence: .exact,
                headline: "Claude usage refreshed"
            ),
            snapshot: nil,
            replacementSessionKey: "replacement-session-key"
        )))

        _ = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: "old-session-key"
            )
        )
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: secretStore,
            claudeClient: client,
            snapshotLoader: FakeSnapshotLoader(),
            now: { now }
        )

        _ = await coordinator.refreshProviders(trigger: .manual)

        let savedSecret = try await secretStore.loadSecret(
            for: ProviderSecretKey(
                providerId: .claude,
                accountId: "acct_1",
                purpose: ClaudeAccountSettings.sessionKeyPurpose
            )
        )
        let setupState = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).setupState(accountId: "acct_1")

        XCTAssertEqual(savedSecret, "replacement-session-key")
        XCTAssertNil(setupState?.renderedSessionKey)
        XCTAssertFalse(String(describing: setupState).contains("replacement-session-key"))
    }

    func testExpiredClaudeAuthMarksAccountExpiredAndReturnsExpiredState() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let secretStore = InMemorySecretStore()
        let client = FakeClaudeUsageClient()
        await client.enqueue(.failure(.httpStatus(401)))
        _ = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: "stored-session-key"
            )
        )
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: secretStore,
            claudeClient: client,
            snapshotLoader: FakeSnapshotLoader(),
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let setupState = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).setupState(accountId: "acct_1")

        XCTAssertEqual(outcome.appState.provider(for: .claude)?.status, .expired)
        XCTAssertEqual(setupState?.secretState.status, .expired)
        XCTAssertEqual(setupState?.lastErrorDescription, "Claude auth expired.")
        XCTAssertTrue(outcome.diagnostics.contains("Claude auth expired."))
        XCTAssertTrue(outcome.diagnosticEvents.contains {
            $0.providerId == .claude &&
                $0.summary == "Claude auth expired." &&
                $0.details["reason"] == "httpStatus:401"
        })
        XCTAssertFalse(String(describing: outcome.diagnosticEvents).contains("acct_1"))
    }

    func testNetworkFailurePreservesLastSuccessfulNonSecretSnapshotAsStale() async throws {
        let firstNow = Date(timeIntervalSince1970: 1_700_000_000)
        let dateBox = TestDateBox(firstNow)
        let store = ProviderConfigurationStore(userDefaults: isolatedDefaults())
        let secretStore = InMemorySecretStore()
        let client = FakeClaudeUsageClient()
        await client.enqueue(.success(ClaudeUsageClientResult(
            response: ClaudeUsageResponse(sections: []),
            providerState: ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .configured,
                confidence: .exact,
                headline: "Claude usage refreshed"
            ),
            snapshot: ClaudeUsageSnapshot(
                recordedAt: firstNow,
                weeklyUtilizationPercent: 44,
                weeklyResetAt: firstNow.addingTimeInterval(3 * 60 * 60)
            )
        )))
        await client.enqueue(.failure(.networkUnavailable))
        _ = try await ClaudeAccountSettings(
            configurationStore: store,
            secretStore: secretStore
        ).saveCredentials(
            ClaudeCredentialInput(
                accountId: "acct_1",
                label: "Work",
                organizationId: "org_1",
                sessionKey: "stored-session-key"
            )
        )
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: secretStore,
            claudeClient: client,
            snapshotLoader: FakeSnapshotLoader(),
            now: { dateBox.current }
        )

        _ = await coordinator.refreshProviders(trigger: .manual)
        dateBox.current = firstNow.addingTimeInterval(60)
        let staleOutcome = await coordinator.refreshProviders(trigger: .manual)

        let claude = staleOutcome.appState.provider(for: .claude)
        XCTAssertEqual(claude?.status, .stale)
        XCTAssertEqual(claude?.confidence, .estimated)
        XCTAssertEqual(claude?.primaryValue, "44%")
        XCTAssertEqual(claude?.lastUpdatedAt, firstNow)
        XCTAssertEqual(claude?.resetWindow?.resetsAt, firstNow.addingTimeInterval(3 * 60 * 60))
        XCTAssertTrue(staleOutcome.diagnostics.contains("Claude refresh failed: networkUnavailable."))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PitwallAppSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private actor FakeClaudeUsageClient: ClaudeUsageClienting {
    enum Response: Sendable {
        case success(ClaudeUsageClientResult)
        case failure(ClaudeUsageClientError)
    }

    private var responses: [Response] = []
    private var requestedSessionKeys: [String] = []
    private var requestedAccountIds: [String] = []

    func enqueue(_ response: Response) {
        responses.append(response)
    }

    func sessionKeys() -> [String] {
        requestedSessionKeys
    }

    func accountIds() -> [String] {
        requestedAccountIds
    }

    func fetchUsage(
        account: ClaudeAccountMetadata,
        sessionKey: String,
        retainedSnapshots: [UsageSnapshot],
        now: Date
    ) async throws -> ClaudeUsageClientResult {
        requestedAccountIds.append(account.id)
        requestedSessionKeys.append(sessionKey)

        guard !responses.isEmpty else {
            throw ClaudeUsageClientError.networkUnavailable
        }

        switch responses.removeFirst() {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}

private actor FakeCodexStatusProvider: CodexAuthStatusProviding {
    let state: CodexSetupState

    init(state: CodexSetupState) {
        self.state = state
    }

    func status() async -> CodexSetupState {
        state
    }
}

private final class FakeSnapshotLoader: LocalProviderSnapshotLoading, @unchecked Sendable {
    private(set) var codexLoadCount = 0
    private(set) var geminiLoadCount = 0

    private let codexSnapshot: LocalProviderFileSnapshot
    private let geminiSnapshot: LocalProviderFileSnapshot

    init(
        codexSnapshot: LocalProviderFileSnapshot = LocalProviderFileSnapshot(homePath: "/codex", files: [:]),
        geminiSnapshot: LocalProviderFileSnapshot = LocalProviderFileSnapshot(homePath: "/gemini", files: [:])
    ) {
        self.codexSnapshot = codexSnapshot
        self.geminiSnapshot = geminiSnapshot
    }

    func loadCodexSnapshot() throws -> LocalProviderFileSnapshot {
        codexLoadCount += 1
        return codexSnapshot
    }

    func loadGeminiSnapshot() throws -> LocalProviderFileSnapshot {
        geminiLoadCount += 1
        return geminiSnapshot
    }
}

private final class TestDateBox: @unchecked Sendable {
    var current: Date

    init(_ current: Date) {
        self.current = current
    }
}
