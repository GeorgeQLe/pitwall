import Foundation
import PitwallCore

public protocol ClaudeUsageClienting: Sendable {
    func fetchUsage(
        account: ClaudeAccountMetadata,
        sessionKey: String,
        retainedSnapshots: [UsageSnapshot],
        now: Date
    ) async throws -> ClaudeUsageClientResult
}

extension ClaudeUsageClient: ClaudeUsageClienting {}

public struct ProviderRefreshOutcome: Equatable, Sendable {
    public var appState: AppProviderState
    public var nextClaudeRefreshAt: Date?
    public var diagnostics: [String]

    public init(
        appState: AppProviderState,
        nextClaudeRefreshAt: Date? = nil,
        diagnostics: [String] = []
    ) {
        self.appState = appState
        self.nextClaudeRefreshAt = nextClaudeRefreshAt
        self.diagnostics = diagnostics
    }
}

public actor ProviderRefreshCoordinator {
    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore
    private let claudeClient: any ClaudeUsageClienting
    private let snapshotLoader: any LocalProviderSnapshotLoading
    private let pollingPolicy: PollingPolicy
    private let now: @Sendable () -> Date

    private var claudeFailureState = RefreshFailureState()
    private var lastClaudeSnapshotByAccountId: [String: ClaudeUsageSnapshot] = [:]
    private var lastClaudeRefreshAttemptAt: Date?

    public init(
        configurationStore: ProviderConfigurationStore,
        secretStore: any ProviderSecretStore,
        claudeClient: any ClaudeUsageClienting = ClaudeUsageClient(),
        snapshotLoader: any LocalProviderSnapshotLoading = LocalProviderSnapshotLoader(),
        pollingPolicy: PollingPolicy = PollingPolicy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configurationStore = configurationStore
        self.secretStore = secretStore
        self.claudeClient = claudeClient
        self.snapshotLoader = snapshotLoader
        self.pollingPolicy = pollingPolicy
        self.now = now
    }

    public func refreshProviders(
        trigger: RefreshTrigger = .automatic
    ) async -> ProviderRefreshOutcome {
        let refreshDate = now()
        let configuration = await configurationStore.load()
        var diagnostics: [String] = []

        let claudeState = await refreshClaude(
            configuration: configuration,
            trigger: trigger,
            now: refreshDate,
            diagnostics: &diagnostics
        )
        let codexState = refreshCodex(diagnostics: &diagnostics)
        let geminiState = refreshGemini(diagnostics: &diagnostics)

        let nextClaudeRefreshAt = pollingPolicy.nextClaudeRefreshDate(
            lastRefreshAt: lastClaudeRefreshAttemptAt,
            resetAt: claudeState.resetWindow?.resetsAt,
            failureState: claudeFailureState,
            trigger: .automatic,
            now: refreshDate
        )

        return ProviderRefreshOutcome(
            appState: AppProviderState(
                providers: [claudeState, codexState, geminiState],
                selectedProviderId: configuration.userPreferences.pinnedProviderId ?? .claude
            ),
            nextClaudeRefreshAt: nextClaudeRefreshAt,
            diagnostics: diagnostics
        )
    }

    public func testClaudeConnection(accountId: String? = nil) async -> ProviderState {
        let configuration = await configurationStore.load()
        var diagnostics: [String] = []

        if let accountId,
           configuration.claudeAccounts.contains(where: { $0.id == accountId }) {
            var scoped = configuration
            scoped.selectedClaudeAccountId = accountId
            return await refreshClaude(
                configuration: scoped,
                trigger: .testConnection,
                now: now(),
                diagnostics: &diagnostics
            )
        }

        return await refreshClaude(
            configuration: configuration,
            trigger: .testConnection,
            now: now(),
            diagnostics: &diagnostics
        )
    }

    private func refreshClaude(
        configuration: ProviderConfigurationSnapshot,
        trigger: RefreshTrigger,
        now refreshDate: Date,
        diagnostics: inout [String]
    ) async -> ProviderState {
        guard let account = selectedClaudeAccount(in: configuration) else {
            return missingClaudeState(
                headline: "Claude credentials missing",
                explanation: "Add Claude session credentials to enable exact Claude usage refresh."
            )
        }

        let lastSnapshot = lastClaudeSnapshotByAccountId[account.id]
        guard pollingPolicy.shouldAttemptRefresh(
            lastRefreshAt: lastClaudeRefreshAttemptAt,
            resetAt: lastSnapshot?.weeklyResetAt,
            failureState: claudeFailureState,
            trigger: trigger,
            now: refreshDate
        ) else {
            return ClaudeUsageParser.normalizedErrorState(
                for: .networkUnavailable,
                account: account.metadata,
                lastSuccessfulSnapshot: lastSnapshot,
                now: refreshDate
            )
        }

        let key = ProviderSecretKey(
            providerId: .claude,
            accountId: account.id,
            purpose: ClaudeAccountSettings.sessionKeyPurpose
        )

        guard let sessionKey = try? await secretStore.loadSecret(for: key),
              !sessionKey.isEmpty else {
            return missingClaudeState(
                headline: "Claude session key missing",
                explanation: "Claude account metadata exists, but the session key is not configured in secure storage."
            )
        }

        lastClaudeRefreshAttemptAt = refreshDate

        do {
            let result = try await claudeClient.fetchUsage(
                account: account.metadata,
                sessionKey: sessionKey,
                retainedSnapshots: usageSnapshots(for: account.id),
                now: refreshDate
            )

            claudeFailureState = RefreshFailureState()
            if let snapshot = result.snapshot {
                lastClaudeSnapshotByAccountId[account.id] = snapshot
            }
            if let replacementSessionKey = result.replacementSessionKey,
               replacementSessionKey != sessionKey {
                try? await secretStore.save(replacementSessionKey, for: key)
            }
            try? await updateClaudeAccountAfterSuccess(accountId: account.id, now: refreshDate)
            return result.providerState
        } catch let error as ClaudeUsageClientError {
            return await handleClaudeFailure(
                error.reason,
                account: account,
                lastSnapshot: lastSnapshot,
                refreshDate: refreshDate,
                diagnostics: &diagnostics
            )
        } catch {
            return await handleClaudeFailure(
                .networkUnavailable,
                account: account,
                lastSnapshot: lastSnapshot,
                refreshDate: refreshDate,
                diagnostics: &diagnostics
            )
        }
    }

    private func handleClaudeFailure(
        _ reason: ClaudeUsageErrorReason,
        account: ClaudeAccountConfiguration,
        lastSnapshot: ClaudeUsageSnapshot?,
        refreshDate: Date,
        diagnostics: inout [String]
    ) async -> ProviderState {
        switch reason {
        case .httpStatus(401), .httpStatus(403):
            claudeFailureState.consecutiveNetworkFailures = 0
            try? await ClaudeAccountSettings(
                configurationStore: configurationStore,
                secretStore: secretStore
            ).markExpired(
                accountId: account.id,
                errorDescription: "Claude auth expired."
            )
            diagnostics.append("Claude auth expired for account \(account.id).")

        case .networkUnavailable, .decodingFailed, .unknown, .httpStatus:
            claudeFailureState.consecutiveNetworkFailures += 1
            diagnostics.append("Claude refresh failed: \(diagnosticValue(for: reason)).")
        }

        return ClaudeUsageParser.normalizedErrorState(
            for: reason,
            account: account.metadata,
            lastSuccessfulSnapshot: lastSnapshot,
            now: refreshDate
        )
    }

    private func refreshCodex(diagnostics: inout [String]) -> ProviderState {
        do {
            let snapshot = try snapshotLoader.loadCodexSnapshot()
            return try CodexLocalDetector().detect(from: snapshot)
        } catch {
            diagnostics.append("Codex passive scan failed.")
            return degradedLocalState(
                providerId: .codex,
                displayName: "Codex",
                headline: "Codex local scan unavailable"
            )
        }
    }

    private func refreshGemini(diagnostics: inout [String]) -> ProviderState {
        do {
            let snapshot = try snapshotLoader.loadGeminiSnapshot()
            return try GeminiLocalDetector().detect(from: snapshot)
        } catch {
            diagnostics.append("Gemini passive scan failed.")
            return degradedLocalState(
                providerId: .gemini,
                displayName: "Gemini",
                headline: "Gemini local scan unavailable"
            )
        }
    }

    private func selectedClaudeAccount(
        in configuration: ProviderConfigurationSnapshot
    ) -> ClaudeAccountConfiguration? {
        if let selectedId = configuration.selectedClaudeAccountId,
           let selected = configuration.claudeAccounts.first(where: { $0.id == selectedId }) {
            return selected
        }

        return configuration.claudeAccounts.first
    }

    private func usageSnapshots(for accountId: String) -> [UsageSnapshot] {
        guard let snapshot = lastClaudeSnapshotByAccountId[accountId] else {
            return []
        }

        return [
            UsageSnapshot(
                recordedAt: snapshot.recordedAt,
                weeklyUtilizationPercent: snapshot.weeklyUtilizationPercent
            )
        ]
    }

    private func updateClaudeAccountAfterSuccess(accountId: String, now: Date) async throws {
        try await configurationStore.update { snapshot in
            var snapshot = snapshot
            snapshot.claudeAccounts = snapshot.claudeAccounts.map { account in
                guard account.id == accountId else {
                    return account
                }

                var account = account
                account.isAuthExpired = false
                account.lastSuccessfulRefreshAt = now
                account.lastErrorDescription = nil
                return account
            }
            return snapshot
        }
    }

    private func missingClaudeState(
        headline: String,
        explanation: String
    ) -> ProviderState {
        ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: headline,
            confidenceExplanation: explanation,
            actions: [
                ProviderAction(kind: .configure, title: "Configure Claude"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ]
        )
    }

    private func degradedLocalState(
        providerId: ProviderID,
        displayName: String,
        headline: String
    ) -> ProviderState {
        ProviderState(
            providerId: providerId,
            displayName: displayName,
            status: .degraded,
            confidence: .observedOnly,
            headline: headline,
            confidenceExplanation: "\(displayName) passive metadata could not be scanned; no raw provider content was persisted.",
            actions: [
                ProviderAction(kind: .refresh, title: "Scan local evidence"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ]
        )
    }

    private func diagnosticValue(for reason: ClaudeUsageErrorReason) -> String {
        switch reason {
        case let .httpStatus(status):
            return "httpStatus:\(status)"
        case .networkUnavailable:
            return "networkUnavailable"
        case .decodingFailed:
            return "decodingFailed"
        case let .unknown(value):
            return "unknown:\(value)"
        }
    }
}
