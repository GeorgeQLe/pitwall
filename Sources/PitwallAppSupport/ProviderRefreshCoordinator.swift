import Foundation
import PitwallCore
import PitwallShared

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
    public var diagnosticEvents: [DiagnosticEvent]

    public init(
        appState: AppProviderState,
        nextClaudeRefreshAt: Date? = nil,
        diagnostics: [String] = [],
        diagnosticEvents: [DiagnosticEvent] = []
    ) {
        self.appState = appState
        self.nextClaudeRefreshAt = nextClaudeRefreshAt
        self.diagnostics = diagnostics
        self.diagnosticEvents = diagnosticEvents
    }
}

private extension ISO8601DateFormatter {
    static let pitwallAppSupport: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

public actor ProviderRefreshCoordinator {
    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore
    private let claudeClient: any ClaudeUsageClienting
    private let snapshotLoader: any LocalProviderSnapshotLoading
    private let codexAuthStatusProvider: (any CodexAuthStatusProviding)?
    private let historyStore: ProviderHistoryStore
    private let diagnosticEventStore: DiagnosticEventStore
    private let diagnosticsRedactor: DiagnosticsRedactor
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
        codexAuthStatusProvider: (any CodexAuthStatusProviding)? = nil,
        historyStore: ProviderHistoryStore = ProviderHistoryStore(),
        diagnosticEventStore: DiagnosticEventStore = DiagnosticEventStore(),
        diagnosticsRedactor: DiagnosticsRedactor = DiagnosticsRedactor(),
        pollingPolicy: PollingPolicy = PollingPolicy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configurationStore = configurationStore
        self.secretStore = secretStore
        self.claudeClient = claudeClient
        self.snapshotLoader = snapshotLoader
        self.codexAuthStatusProvider = codexAuthStatusProvider
        self.historyStore = historyStore
        self.diagnosticEventStore = diagnosticEventStore
        self.diagnosticsRedactor = diagnosticsRedactor
        self.pollingPolicy = pollingPolicy
        self.now = now
    }

    public func refreshProviders(
        trigger: RefreshTrigger = .automatic
    ) async -> ProviderRefreshOutcome {
        let refreshDate = now()
        let configuration = await configurationStore.load()
        var diagnostics: [String] = []
        var diagnosticEvents: [DiagnosticEvent] = []

        let claudeState = await refreshClaude(
            configuration: configuration,
            trigger: trigger,
            now: refreshDate,
            diagnostics: &diagnostics,
            diagnosticEvents: &diagnosticEvents
        )
        let codexState = await refreshCodex(
            diagnostics: &diagnostics,
            diagnosticEvents: &diagnosticEvents,
            now: refreshDate
        )
        let geminiState = refreshGemini(
            diagnostics: &diagnostics,
            diagnosticEvents: &diagnosticEvents,
            now: refreshDate
        )

        let nextClaudeRefreshAt = pollingPolicy.nextClaudeRefreshDate(
            lastRefreshAt: lastClaudeRefreshAttemptAt,
            resetAt: claudeState.resetWindow?.resetsAt,
            failureState: claudeFailureState,
            trigger: .automatic,
            now: refreshDate
        )

        let redactedDiagnosticEvents = diagnosticEvents.map(diagnosticsRedactor.redact)
        try? await diagnosticEventStore.append(redactedDiagnosticEvents, now: refreshDate)

        return ProviderRefreshOutcome(
            appState: AppProviderState(
                providers: [claudeState, codexState, geminiState],
                selectedProviderId: configuration.userPreferences.pinnedProviderId ?? .claude
            ),
            nextClaudeRefreshAt: nextClaudeRefreshAt,
            diagnostics: diagnostics,
            diagnosticEvents: redactedDiagnosticEvents
        )
    }

    public func testClaudeConnection(accountId: String? = nil) async -> ProviderState {
        let configuration = await configurationStore.load()
        var diagnostics: [String] = []
        var diagnosticEvents: [DiagnosticEvent] = []

        if let accountId,
           configuration.claudeAccounts.contains(where: { $0.id == accountId }) {
            var scoped = configuration
            scoped.selectedClaudeAccountId = accountId
            return await refreshClaude(
                configuration: scoped,
                trigger: .testConnection,
                now: now(),
                diagnostics: &diagnostics,
                diagnosticEvents: &diagnosticEvents
            )
        }

        return await refreshClaude(
            configuration: configuration,
            trigger: .testConnection,
            now: now(),
            diagnostics: &diagnostics,
            diagnosticEvents: &diagnosticEvents
        )
    }

    private func refreshClaude(
        configuration: ProviderConfigurationSnapshot,
        trigger: RefreshTrigger,
        now refreshDate: Date,
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent]
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
            let retainedSnapshots = await usageSnapshots(for: account.id, now: refreshDate)
            let result = try await claudeClient.fetchUsage(
                account: account.metadata,
                sessionKey: sessionKey,
                retainedSnapshots: retainedSnapshots,
                now: refreshDate
            )

            claudeFailureState = RefreshFailureState()
            if let snapshot = result.snapshot {
                lastClaudeSnapshotByAccountId[account.id] = snapshot
                try? await historyStore.append(
                    historySnapshot(
                        from: snapshot,
                        accountId: account.id,
                        providerState: result.providerState
                    ),
                    now: refreshDate
                )
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
                diagnostics: &diagnostics,
                diagnosticEvents: &diagnosticEvents
            )
        } catch {
            return await handleClaudeFailure(
                .networkUnavailable,
                account: account,
                lastSnapshot: lastSnapshot,
                refreshDate: refreshDate,
                diagnostics: &diagnostics,
                diagnosticEvents: &diagnosticEvents
            )
        }
    }

    private func handleClaudeFailure(
        _ reason: ClaudeUsageErrorReason,
        account: ClaudeAccountConfiguration,
        lastSnapshot: ClaudeUsageSnapshot?,
        refreshDate: Date,
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent]
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
            diagnostics.append("Claude auth expired.")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .claude,
                occurredAt: refreshDate,
                summary: "Claude auth expired.",
                details: ["reason": diagnosticValue(for: reason)]
            ))

        case .networkUnavailable, .decodingFailed, .unknown, .httpStatus:
            claudeFailureState.consecutiveNetworkFailures += 1
            diagnostics.append("Claude refresh failed: \(diagnosticValue(for: reason)).")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .claude,
                occurredAt: refreshDate,
                summary: "Claude refresh failed.",
                details: ["reason": diagnosticValue(for: reason)]
            ))
        }

        return ClaudeUsageParser.normalizedErrorState(
            for: reason,
            account: account.metadata,
            lastSuccessfulSnapshot: lastSnapshot,
            now: refreshDate
        )
    }

    private func refreshCodex(
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent],
        now refreshDate: Date
    ) async -> ProviderState {
        do {
            let snapshot = try snapshotLoader.loadCodexSnapshot()
            let passiveState = try CodexLocalDetector().detect(from: snapshot)
            guard let codexAuthStatusProvider else {
                return passiveState
            }

            let setupState = await codexAuthStatusProvider.status()
            return mergedCodexState(passiveState: passiveState, setupState: setupState)
        } catch {
            diagnostics.append("Codex passive scan failed.")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .codex,
                occurredAt: refreshDate,
                summary: "Codex passive scan failed.",
                details: ["reason": "scanUnavailable"]
            ))
            return degradedLocalState(
                providerId: .codex,
                displayName: "Codex",
                headline: "Codex local scan unavailable"
            )
        }
    }

    private func mergedCodexState(
        passiveState: ProviderState,
        setupState: CodexSetupState
    ) -> ProviderState {
        switch setupState.status {
        case .configured:
            var merged = passiveState
            merged.status = .configured
            merged.headline = setupState.headline
            merged.secondaryValue = setupState.authMode?.displayName ?? passiveState.secondaryValue ?? "CLI auth present"
            merged.confidenceExplanation = "\(passiveState.confidenceExplanation) Login verified through the Codex CLI."
            if merged.actions.isEmpty {
                merged.actions = [
                    ProviderAction(kind: .refresh, title: "Scan local evidence"),
                    ProviderAction(kind: .openSettings, title: "Open settings")
                ]
            }
            return merged

        case .missing:
            var merged = passiveState
            if passiveState.status == .missingConfiguration,
               passiveState.headline == "Codex configuration missing" {
                return passiveState
            }
            merged.status = .missingConfiguration
            merged.confidence = .observedOnly
            merged.headline = setupState.headline
            merged.secondaryValue = "CLI auth not detected"
            merged.confidenceExplanation = setupState.detail
            merged.actions = [
                ProviderAction(kind: .configure, title: "Configure Codex"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ]
            return merged

        case .unavailable:
            return passiveState
        }
    }

    private func refreshGemini(
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent],
        now refreshDate: Date
    ) -> ProviderState {
        do {
            let snapshot = try snapshotLoader.loadGeminiSnapshot()
            return try GeminiLocalDetector().detect(from: snapshot)
        } catch {
            diagnostics.append("Gemini passive scan failed.")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .gemini,
                occurredAt: refreshDate,
                summary: "Gemini passive scan failed.",
                details: ["reason": "scanUnavailable"]
            ))
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

    private func usageSnapshots(
        for accountId: String,
        now refreshDate: Date
    ) async -> [UsageSnapshot] {
        let retainedSnapshots = await historyStore.retainedUsageSnapshots(
            providerId: .claude,
            accountId: accountId,
            now: refreshDate
        )

        if !retainedSnapshots.isEmpty {
            return retainedSnapshots
        }

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

    private func historySnapshot(
        from snapshot: ClaudeUsageSnapshot,
        accountId: String,
        providerState: ProviderState
    ) -> ProviderHistorySnapshot {
        ProviderHistorySnapshot(
            accountId: accountId,
            recordedAt: snapshot.recordedAt,
            providerId: providerState.providerId,
            confidence: providerState.confidence,
            sessionUtilizationPercent: usageRowValue(named: "Session", in: providerState)?.utilization,
            weeklyUtilizationPercent: snapshot.weeklyUtilizationPercent,
            sessionResetAt: usageRowValue(named: "Session", in: providerState)?.resetAt,
            weeklyResetAt: snapshot.weeklyResetAt,
            headline: providerState.headline
        )
    }

    private func usageRowValue(
        named label: String,
        in providerState: ProviderState
    ) -> (utilization: Double, resetAt: Date?)? {
        guard
            let rawValue = providerState.payloads.first(where: { $0.source == "usageRows" })?
                .values[label]
        else {
            return nil
        }

        let parts = rawValue.split(separator: "|", omittingEmptySubsequences: false)
        guard let utilization = parts.first.flatMap({ Double($0) }) else {
            return nil
        }

        let resetAt = parts.dropFirst().first.flatMap {
            ISO8601DateFormatter.pitwallAppSupport.date(from: String($0))
        }
        return (utilization, resetAt)
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
