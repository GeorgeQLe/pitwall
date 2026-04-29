import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderRefreshCoordinatorTests: XCTestCase {
    func testMissingClaudeCredentialsDoNotCallClientAndKeepAuthBackedPassiveProvidersVisible() async {
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
                    files: [
                        "settings.json": #"{"selectedAuthType":"oauth-personal"}"#,
                        "oauth_creds.json": ""
                    ]
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

    func testGeminiSettingsWithoutOAuthRemainUnconfigured() async {
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: ["settings.json": #"{"selectedAuthType":"oauth-personal"}"#]
                )
            ),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let gemini = outcome.appState.provider(for: .gemini)

        XCTAssertEqual(gemini?.status, .missingConfiguration)
        XCTAssertEqual(gemini?.headline, "Gemini login not detected")
        XCTAssertEqual(gemini?.secondaryValue, "CLI auth not detected")
        XCTAssertFalse(outcome.appState.trackedProviders.contains { $0.providerId == .gemini })
    }

    func testGeminiLocalAuthWithoutQuotaSignalStaysOutOfTrackedRotation() async {
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: [
                        "settings.json": #"{"selectedAuthType":"oauth-personal","profile":"work"}"#,
                        "oauth_creds.json": ""
                    ]
                )
            ),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let gemini = outcome.appState.provider(for: .gemini)

        XCTAssertEqual(gemini?.status, .configured)
        XCTAssertEqual(gemini?.confidence, .estimated)
        XCTAssertFalse(outcome.appState.trackedProviders.contains { $0.providerId == .gemini })
        XCTAssertEqual(MenuBarStatusFormatter().menuBarTitle(appState: outcome.appState), "Configure")
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

    func testCodexTelemetryUpgradesPassiveStateToProviderSuppliedUsage() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "auth.json": "", "history.jsonl": ""]
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
            codexUsageClient: FakeCodexUsageClient(result: .success(CodexUsageClientResult(
                rateLimits: CodexRateLimitSnapshot(
                    limitId: "codex",
                    primary: CodexRateLimitWindow(
                        usedPercent: 30,
                        windowDurationMinutes: 300,
                        resetsAt: now.addingTimeInterval(3 * 60 * 60)
                    ),
                    secondary: CodexRateLimitWindow(
                        usedPercent: 26,
                        windowDurationMinutes: 10_080,
                        resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60)
                    ),
                    credits: CodexCreditsSnapshot(hasCredits: false, unlimited: false, balance: "0"),
                    planType: "pro"
                ),
                rateLimitsByLimitId: [
                    "codex": CodexRateLimitSnapshot(
                        limitId: "codex",
                        primary: CodexRateLimitWindow(
                            usedPercent: 30,
                            windowDurationMinutes: 300,
                            resetsAt: now.addingTimeInterval(3 * 60 * 60)
                        ),
                        secondary: CodexRateLimitWindow(
                            usedPercent: 26,
                            windowDurationMinutes: 10_080,
                            resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60)
                        ),
                        credits: CodexCreditsSnapshot(hasCredits: false, unlimited: false, balance: "0"),
                        planType: "pro"
                    ),
                    "codex_bengalfox": CodexRateLimitSnapshot(
                        limitId: "codex_bengalfox",
                        limitName: "GPT-5.3-Codex-Spark",
                        primary: CodexRateLimitWindow(usedPercent: 0),
                        secondary: CodexRateLimitWindow(usedPercent: 0),
                        planType: "pro"
                    )
                ],
                fetchedAt: now
            ))),
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = outcome.appState.provider(for: .codex)
        let rateLimitPayload = codex?.payloads.first { $0.source == "codex-rate-limits" }
        let bucketsPayload = codex?.payloads.first { $0.source == "codex-rate-limit-buckets" }

        XCTAssertEqual(codex?.status, .configured)
        XCTAssertEqual(codex?.confidence, .providerSupplied)
        XCTAssertEqual(codex?.headline, "Codex usage refreshed")
        XCTAssertEqual(codex?.primaryValue, "70% session left")
        XCTAssertEqual(codex?.secondaryValue, "Pro")
        XCTAssertEqual(codex?.resetWindow?.resetsAt, now.addingTimeInterval(3 * 24 * 60 * 60))
        XCTAssertEqual(codex?.pacingState?.weeklyUtilizationPercent, 26)
        XCTAssertEqual(codex?.pacingState?.sessionPace?.remainingWindowDuration, 3 * 60 * 60)
        XCTAssertEqual(rateLimitPayload?.values["planType"], "pro")
        XCTAssertEqual(rateLimitPayload?.values["credits"], "false|false|0")
        XCTAssertTrue(bucketsPayload?.values["codex_bengalfox"]?.contains("GPT-5.3-Codex-Spark") == true)
    }

    func testCodexTelemetryUsesTopLevelSlashStatusPayloadWhenBucketMapDiffers() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "auth.json": "", "history.jsonl": ""]
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
            codexUsageClient: FakeCodexUsageClient(result: .success(CodexUsageClientResult(
                rateLimits: CodexRateLimitSnapshot(
                    limitId: "codex",
                    primary: CodexRateLimitWindow(
                        usedPercent: 61,
                        windowDurationMinutes: 300,
                        resetsAt: now.addingTimeInterval(60 * 60)
                    ),
                    secondary: CodexRateLimitWindow(
                        usedPercent: 44,
                        windowDurationMinutes: 10_080,
                        resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)
                    ),
                    planType: "pro"
                ),
                rateLimitsByLimitId: [
                    "codex": CodexRateLimitSnapshot(
                        limitId: "codex",
                        primary: CodexRateLimitWindow(
                            usedPercent: 12,
                            windowDurationMinutes: 300,
                            resetsAt: now.addingTimeInterval(5 * 60 * 60)
                        ),
                        secondary: CodexRateLimitWindow(
                            usedPercent: 8,
                            windowDurationMinutes: 10_080,
                            resetsAt: now.addingTimeInterval(6 * 24 * 60 * 60)
                        ),
                        planType: "pro"
                    )
                ],
                fetchedAt: now
            ))),
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = outcome.appState.provider(for: .codex)
        let text = codex.map {
            MenuBarStatusFormatter().menuBarTitle(
                provider: $0,
                preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
                now: now
            )
        }

        XCTAssertEqual(codex?.primaryValue, "39% session left")
        XCTAssertEqual(codex?.pacingState?.weeklyUtilizationPercent, 44)
        XCTAssertEqual(codex?.pacingState?.sessionPace?.remainingWindowDuration, 60 * 60)
        XCTAssertTrue(text?.contains("61%") == true)
        XCTAssertTrue(text?.contains("44%/w") == true)
        XCTAssertTrue(text?.contains("1h 0m 0s") == true)
    }

    func testCodexTelemetryUsesHistoryForTodayUsageVsDailyTarget() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = isolatedDefaults()
        let historyStore = ProviderHistoryStore(userDefaults: defaults)
        try await historyStore.save([
            ProviderHistorySnapshot(
                accountId: "codex-default",
                recordedAt: now.addingTimeInterval(-60 * 60),
                providerId: .codex,
                confidence: .providerSupplied,
                weeklyUtilizationPercent: 20,
                weeklyResetAt: now.addingTimeInterval(4 * 24 * 60 * 60),
                headline: "Codex usage refreshed"
            )
        ])
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: defaults),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "auth.json": "", "history.jsonl": ""]
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
            codexUsageClient: FakeCodexUsageClient(result: .success(CodexUsageClientResult(
                rateLimits: CodexRateLimitSnapshot(
                    limitId: "codex",
                    primary: CodexRateLimitWindow(
                        usedPercent: 24,
                        windowDurationMinutes: 300,
                        resetsAt: now.addingTimeInterval(3 * 60 * 60)
                    ),
                    secondary: CodexRateLimitWindow(
                        usedPercent: 26,
                        windowDurationMinutes: 10_080,
                        resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)
                    ),
                    planType: "pro"
                ),
                fetchedAt: now
            ))),
            historyStore: historyStore,
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = try XCTUnwrap(outcome.appState.provider(for: .codex))
        let title = MenuBarStatusFormatter().menuBarTitle(
            provider: codex,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
            now: now
        )
        let snapshots = await historyStore.retainedSnapshots(
            providerId: .codex,
            accountId: "codex-default",
            now: now
        )

        XCTAssertEqual(codex.pacingState?.todayUsage?.status, .estimatedFromSameDayBaseline)
        XCTAssertEqual(codex.pacingState?.todayUsage?.utilizationDeltaPercent ?? 0, 6, accuracy: 0.001)
        XCTAssertEqual(codex.pacingState?.dailyBudget?.dailyBudgetPercent ?? 0, 18.5, accuracy: 0.001)
        XCTAssertTrue(title.contains("🛌 6%/18.5%/day"))
        XCTAssertEqual(snapshots.last?.weeklyUtilizationPercent, 26)
    }

    func testCodexTelemetryFailureFallsBackToPassiveState() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: ProviderConfigurationStore(userDefaults: isolatedDefaults()),
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                codexSnapshot: LocalProviderFileSnapshot(
                    homePath: "/codex",
                    files: ["config.toml": "", "auth.json": "", "history.jsonl": ""]
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
            codexUsageClient: FakeCodexUsageClient(result: .failure(.appServerError("network unavailable"))),
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let codex = outcome.appState.provider(for: .codex)

        XCTAssertEqual(codex?.status, .configured)
        XCTAssertEqual(codex?.confidence, .estimated)
        XCTAssertEqual(codex?.headline, "Connected with ChatGPT")
        XCTAssertNil(codex?.payloads.first { $0.source == "codex-rate-limits" })
        XCTAssertTrue(outcome.diagnostics.contains("Codex telemetry unavailable."))
        XCTAssertTrue(outcome.diagnosticEvents.contains {
            $0.providerId == .codex &&
                $0.summary == "Codex telemetry unavailable." &&
                $0.details["reason"] == "usageRefreshUnavailable"
        })
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

    func testGeminiTelemetrySuccessUsesProviderSuppliedQuotaAndStoresHistory() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = isolatedDefaults()
        let store = ProviderConfigurationStore(userDefaults: defaults)
        try await store.save(ProviderConfigurationSnapshot(
            providerProfiles: [
                ProviderProfileConfiguration(providerId: .claude),
                ProviderProfileConfiguration(providerId: .codex),
                ProviderProfileConfiguration(providerId: .gemini, telemetryEnabled: true)
            ]
        ))
        let historyStore = ProviderHistoryStore(userDefaults: defaults)
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: [
                        "settings.json": #"{"selectedAuthType":"oauth-personal"}"#,
                        "oauth_creds.json": ""
                    ]
                )
            ),
            geminiUsageClient: FakeGeminiUsageClient(result: .success(GeminiUsageClientResult(
                projectId: "cloud-ai-project",
                tier: "pro",
                buckets: [
                    GeminiQuotaBucket(
                        modelId: "gemini-2.5-pro",
                        tokenType: "requests",
                        remainingAmount: 800,
                        remainingFraction: 0.8,
                        resetsAt: now.addingTimeInterval(24 * 60 * 60)
                    )
                ],
                fetchedAt: now
            ))),
            historyStore: historyStore,
            now: { now }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let gemini = outcome.appState.provider(for: .gemini)
        let history = await historyStore.load()

        XCTAssertEqual(gemini?.confidence, .providerSupplied)
        XCTAssertEqual(gemini?.headline, "Gemini quota refreshed")
        XCTAssertEqual(gemini?.primaryValue, "20% used")
        XCTAssertEqual(
            gemini?.payloads.first(where: { $0.source == "gemini-quota" })?.values["bucket0.modelId"],
            "gemini-2.5-pro"
        )
        XCTAssertEqual(history.first?.providerId, .gemini)
        XCTAssertEqual(history.first?.weeklyUtilizationPercent ?? 0, 20, accuracy: 0.0001)
    }

    func testGeminiTelemetryFailureFallsBackToPassiveState() async throws {
        let defaults = isolatedDefaults()
        let store = ProviderConfigurationStore(userDefaults: defaults)
        try await store.save(ProviderConfigurationSnapshot(
            providerProfiles: [
                ProviderProfileConfiguration(providerId: .claude),
                ProviderProfileConfiguration(providerId: .codex),
                ProviderProfileConfiguration(providerId: .gemini, telemetryEnabled: true)
            ]
        ))
        let coordinator = ProviderRefreshCoordinator(
            configurationStore: store,
            secretStore: InMemorySecretStore(),
            claudeClient: FakeClaudeUsageClient(),
            snapshotLoader: FakeSnapshotLoader(
                geminiSnapshot: LocalProviderFileSnapshot(
                    homePath: "/gemini",
                    files: [
                        "settings.json": #"{"selectedAuthType":"oauth-personal"}"#,
                        "oauth_creds.json": ""
                    ]
                )
            ),
            geminiUsageClient: FakeGeminiUsageClient(result: .failure(.quotaUnavailable)),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let outcome = await coordinator.refreshProviders(trigger: .manual)
        let gemini = outcome.appState.provider(for: .gemini)

        XCTAssertEqual(gemini?.confidence, .estimated)
        XCTAssertEqual(gemini?.headline, "Gemini local evidence detected")
        XCTAssertTrue(outcome.diagnostics.contains("Gemini telemetry unavailable."))
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

private actor FakeCodexUsageClient: CodexUsageClienting {
    private let result: Result<CodexUsageClientResult, CodexUsageClientError>

    init(result: Result<CodexUsageClientResult, CodexUsageClientError>) {
        self.result = result
    }

    func fetchUsage(now: Date) async throws -> CodexUsageClientResult {
        try result.get()
    }
}

private actor FakeGeminiUsageClient: GeminiUsageClienting {
    private let result: Result<GeminiUsageClientResult, GeminiUsageClientError>

    init(result: Result<GeminiUsageClientResult, GeminiUsageClientError>) {
        self.result = result
    }

    func fetchUsage(now: Date) async throws -> GeminiUsageClientResult {
        try result.get()
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
