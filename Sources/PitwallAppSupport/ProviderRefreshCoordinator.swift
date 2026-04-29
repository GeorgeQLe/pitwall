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
    private static let codexAccountId = "codex-default"
    private static let geminiAccountId = "gemini-default"

    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore
    private let claudeClient: any ClaudeUsageClienting
    private let snapshotLoader: any LocalProviderSnapshotLoading
    private let codexAuthStatusProvider: (any CodexAuthStatusProviding)?
    private let codexUsageClient: (any CodexUsageClienting)?
    private let geminiUsageClient: (any GeminiUsageClienting)?
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
        codexUsageClient: (any CodexUsageClienting)? = nil,
        geminiUsageClient: (any GeminiUsageClienting)? = nil,
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
        self.codexUsageClient = codexUsageClient
        self.geminiUsageClient = geminiUsageClient
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
        let geminiState = await refreshGemini(
            configuration: configuration,
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
            let retainedSnapshots = await usageSnapshots(
                providerId: .claude,
                accountId: account.id,
                now: refreshDate
            )
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
            let mergedState = mergedCodexState(passiveState: passiveState, setupState: setupState)
            return await codexTelemetryState(
                baseState: mergedState,
                setupState: setupState,
                diagnostics: &diagnostics,
                diagnosticEvents: &diagnosticEvents,
                now: refreshDate
            )
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

    private func codexTelemetryState(
        baseState: ProviderState,
        setupState: CodexSetupState,
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent],
        now refreshDate: Date
    ) async -> ProviderState {
        guard let codexUsageClient,
              setupState.status == .configured,
              setupState.authMode != .apiKey else {
            return baseState
        }

        do {
            let result = try await codexUsageClient.fetchUsage(now: refreshDate)
            let retainedSnapshots = await usageSnapshots(
                providerId: .codex,
                accountId: Self.codexAccountId,
                now: refreshDate
            )
            let providerState = codexUsageProviderState(
                baseState: baseState,
                result: result,
                retainedSnapshots: retainedSnapshots,
                now: refreshDate
            )
            try? await historyStore.append(
                codexHistorySnapshot(
                    from: result.preferredRateLimit,
                    providerState: providerState,
                    recordedAt: refreshDate
                ),
                now: refreshDate
            )
            return providerState
        } catch {
            diagnostics.append("Codex telemetry unavailable.")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .codex,
                occurredAt: refreshDate,
                summary: "Codex telemetry unavailable.",
                details: ["reason": "usageRefreshUnavailable"]
            ))

            var fallback = baseState
            fallback.confidenceExplanation = "\(baseState.confidenceExplanation) Codex quota telemetry failed, so Pitwall is showing local evidence only."
            return fallback
        }
    }

    private func codexUsageProviderState(
        baseState: ProviderState,
        result: CodexUsageClientResult,
        retainedSnapshots: [UsageSnapshot],
        now refreshDate: Date
    ) -> ProviderState {
        let snapshot = result.preferredRateLimit
        let weeklyWindow = snapshot.secondary ?? snapshot.primary
        let sessionWindow = snapshot.primary
        let weeklyResetAt = weeklyWindow?.resetsAt
        let sessionResetAt = sessionWindow?.resetsAt
        let weeklyPace = weeklyWindow.flatMap {
            paceEvaluation(for: $0, fallbackMinutes: 7 * 24 * 60, now: refreshDate, isWeekly: true)
        }
        let sessionPace = sessionWindow.flatMap {
            paceEvaluation(for: $0, fallbackMinutes: 5 * 60, now: refreshDate, isWeekly: false)
        }
        let dailyBudget = weeklyWindow.flatMap { window -> DailyBudget? in
            guard let resetAt = window.resetsAt else { return nil }
            return PacingCalculator().dailyBudget(
                weeklyUtilizationPercent: window.usedPercent,
                resetAt: resetAt,
                now: refreshDate,
                retainedSnapshots: retainedSnapshots
            )
        }

        return ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .providerSupplied,
            headline: snapshot.rateLimitReachedType == nil
                ? "Codex usage refreshed"
                : "Codex usage limit reached",
            primaryValue: sessionWindow.map { "\(Self.formatPercent($0.remainingPercent)) left" }
                ?? weeklyWindow.map { "\(Self.formatPercent(100 - $0.usedPercent)) left" },
            secondaryValue: snapshot.limitName ?? Self.displayPlanType(snapshot.planType) ?? baseState.secondaryValue,
            resetWindow: ResetWindow(resetsAt: weeklyResetAt ?? sessionResetAt),
            lastUpdatedAt: refreshDate,
            pacingState: PacingState(
                weeklyUtilizationPercent: weeklyWindow?.usedPercent,
                remainingWindowDuration: (weeklyResetAt ?? sessionResetAt).map {
                    max(0, $0.timeIntervalSince(refreshDate))
                },
                dailyBudget: dailyBudget,
                todayUsage: dailyBudget?.todayUsage,
                weeklyPace: weeklyPace,
                sessionPace: sessionPace
            ),
            confidenceExplanation: "Codex returned provider-supplied rate-limit data through the local CLI app-server.",
            actions: [
                ProviderAction(kind: .refresh, title: "Refresh now"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: baseState.payloads + [
                codexRateLimitPayload(from: snapshot),
                codexRateLimitBucketsPayload(from: result.rateLimitsByLimitId)
            ].compactMap { $0 }
        )
    }

    private func paceEvaluation(
        for window: CodexRateLimitWindow,
        fallbackMinutes: Int,
        now refreshDate: Date,
        isWeekly: Bool
    ) -> PaceEvaluation? {
        guard let resetAt = window.resetsAt else {
            return nil
        }

        let durationMinutes = window.windowDurationMinutes ?? fallbackMinutes
        let windowStart = resetAt.addingTimeInterval(-Double(durationMinutes) * 60)
        let calculator = PacingCalculator()
        return isWeekly
            ? calculator.evaluateWeeklyPace(
                utilizationPercent: window.usedPercent,
                windowStart: windowStart,
                resetAt: resetAt,
                now: refreshDate
            )
            : calculator.evaluateSessionPace(
                utilizationPercent: window.usedPercent,
                windowStart: windowStart,
                resetAt: resetAt,
                now: refreshDate
            )
    }

    private func codexRateLimitPayload(
        from snapshot: CodexRateLimitSnapshot
    ) -> ProviderSpecificPayload {
        var values: [String: String] = [:]
        values["limitId"] = snapshot.limitId
        values["limitName"] = snapshot.limitName
        values["planType"] = snapshot.planType
        values["rateLimitReachedType"] = snapshot.rateLimitReachedType
        if let primary = snapshot.primary {
            values["primary"] = Self.formatCodexWindow(primary)
        }
        if let secondary = snapshot.secondary {
            values["secondary"] = Self.formatCodexWindow(secondary)
        }
        if let credits = snapshot.credits {
            values["credits"] = [
                String(credits.hasCredits),
                String(credits.unlimited),
                credits.balance ?? "unknown"
            ].joined(separator: "|")
        }

        return ProviderSpecificPayload(source: "codex-rate-limits", values: values)
    }

    private func codexRateLimitBucketsPayload(
        from snapshots: [String: CodexRateLimitSnapshot]?
    ) -> ProviderSpecificPayload? {
        guard let snapshots, !snapshots.isEmpty else {
            return nil
        }

        let values = snapshots.reduce(into: [String: String]()) { partial, entry in
            partial[entry.key] = [
                entry.value.limitName ?? entry.key,
                entry.value.primary.map(Self.formatCodexWindow) ?? "unknown",
                entry.value.secondary.map(Self.formatCodexWindow) ?? "unknown"
            ].joined(separator: "|")
        }
        return ProviderSpecificPayload(source: "codex-rate-limit-buckets", values: values)
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
        configuration: ProviderConfigurationSnapshot,
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent],
        now refreshDate: Date
    ) async -> ProviderState {
        do {
            let snapshot = try snapshotLoader.loadGeminiSnapshot()
            let passiveState = try GeminiLocalDetector().detect(from: snapshot)
            let telemetryEnabled = configuration.providerProfiles.first {
                $0.providerId == .gemini
            }?.telemetryEnabled == true

            guard telemetryEnabled else {
                return passiveState
            }

            return await geminiTelemetryState(
                baseState: passiveState,
                diagnostics: &diagnostics,
                diagnosticEvents: &diagnosticEvents,
                now: refreshDate
            )
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

    private func geminiTelemetryState(
        baseState: ProviderState,
        diagnostics: inout [String],
        diagnosticEvents: inout [DiagnosticEvent],
        now refreshDate: Date
    ) async -> ProviderState {
        guard let geminiUsageClient else {
            return baseState
        }

        do {
            let result = try await geminiUsageClient.fetchUsage(now: refreshDate)
            let retainedSnapshots = await usageSnapshots(
                providerId: .gemini,
                accountId: Self.geminiAccountId,
                now: refreshDate
            )
            let providerState = geminiUsageProviderState(
                baseState: baseState,
                result: result,
                retainedSnapshots: retainedSnapshots,
                now: refreshDate
            )
            try? await historyStore.append(
                geminiHistorySnapshot(
                    from: result,
                    providerState: providerState,
                    recordedAt: refreshDate
                ),
                now: refreshDate
            )
            return providerState
        } catch {
            diagnostics.append("Gemini telemetry unavailable.")
            diagnosticEvents.append(DiagnosticEvent(
                providerId: .gemini,
                occurredAt: refreshDate,
                summary: "Gemini telemetry unavailable.",
                details: ["reason": "usageRefreshUnavailable"]
            ))

            var fallback = baseState
            fallback.confidenceExplanation = "\(baseState.confidenceExplanation) Gemini quota telemetry failed, so Pitwall is showing local evidence only."
            return fallback
        }
    }

    private func geminiUsageProviderState(
        baseState: ProviderState,
        result: GeminiUsageClientResult,
        retainedSnapshots: [UsageSnapshot],
        now refreshDate: Date
    ) -> ProviderState {
        let primaryBucket = result.primaryBucket
        let resetAt = primaryBucket?.resetsAt
        let weeklyPercent = primaryBucket?.usedPercent
        let weeklyPace = weeklyPercent.flatMap { percent -> PaceEvaluation? in
            guard let resetAt else { return nil }
            return PacingCalculator().evaluateWeeklyPace(
                utilizationPercent: percent,
                windowStart: resetAt.addingTimeInterval(-24 * 60 * 60),
                resetAt: resetAt,
                now: refreshDate
            )
        }
        let dailyBudget = weeklyPercent.flatMap { percent -> DailyBudget? in
            guard let resetAt else { return nil }
            return PacingCalculator().dailyBudget(
                weeklyUtilizationPercent: percent,
                resetAt: resetAt,
                now: refreshDate,
                retainedSnapshots: retainedSnapshots
            )
        }

        return ProviderState(
            providerId: .gemini,
            displayName: "Gemini",
            status: .configured,
            confidence: .providerSupplied,
            headline: "Gemini quota refreshed",
            primaryValue: weeklyPercent.map { "\(Self.formatPercent(100 - $0)) left" },
            secondaryValue: result.tier ?? baseState.secondaryValue,
            resetWindow: resetAt.map { ResetWindow(resetsAt: $0) },
            lastUpdatedAt: refreshDate,
            pacingState: PacingState(
                weeklyUtilizationPercent: weeklyPercent,
                remainingWindowDuration: resetAt.map { max(0, $0.timeIntervalSince(refreshDate)) },
                dailyBudget: dailyBudget,
                todayUsage: dailyBudget?.todayUsage,
                weeklyPace: weeklyPace
            ),
            confidenceExplanation: "Gemini returned provider-supplied quota data through the existing Gemini CLI Google login.",
            actions: [
                ProviderAction(kind: .refresh, title: "Refresh now"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: baseState.payloads + [
                geminiQuotaPayload(from: result)
            ]
        )
    }

    private func geminiQuotaPayload(from result: GeminiUsageClientResult) -> ProviderSpecificPayload {
        var values: [String: String] = [
            "projectId": result.projectId
        ]
        if let tier = result.tier {
            values["tier"] = tier
        }
        for (index, bucket) in result.buckets.enumerated() {
            let prefix = "bucket\(index)"
            if let modelId = bucket.modelId {
                values["\(prefix).modelId"] = modelId
            }
            if let tokenType = bucket.tokenType {
                values["\(prefix).tokenType"] = tokenType
            }
            if let remainingAmount = bucket.remainingAmount {
                values["\(prefix).remainingAmount"] = Self.formatDecimal(remainingAmount)
            }
            if let remainingFraction = bucket.remainingFraction {
                values["\(prefix).remainingFraction"] = Self.formatDecimal(remainingFraction)
            }
            if let usedPercent = bucket.usedPercent {
                values["\(prefix).usedPercent"] = Self.formatDecimal(usedPercent)
            }
            if let resetsAt = bucket.resetsAt {
                values["\(prefix).resetsAt"] = ISO8601DateFormatter.pitwallAppSupport.string(from: resetsAt)
            }
        }
        return ProviderSpecificPayload(source: "gemini-quota", values: values)
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
        providerId: ProviderID,
        accountId: String,
        now refreshDate: Date
    ) async -> [UsageSnapshot] {
        let retainedSnapshots = await historyStore.retainedUsageSnapshots(
            providerId: providerId,
            accountId: accountId,
            now: refreshDate
        )

        if !retainedSnapshots.isEmpty {
            return retainedSnapshots
        }

        guard providerId == .claude else {
            return []
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

    private func codexHistorySnapshot(
        from snapshot: CodexRateLimitSnapshot,
        providerState: ProviderState,
        recordedAt: Date
    ) -> ProviderHistorySnapshot {
        let weeklyWindow = snapshot.secondary ?? snapshot.primary
        return ProviderHistorySnapshot(
            accountId: Self.codexAccountId,
            recordedAt: recordedAt,
            providerId: .codex,
            confidence: providerState.confidence,
            sessionUtilizationPercent: snapshot.primary?.usedPercent,
            weeklyUtilizationPercent: weeklyWindow?.usedPercent,
            sessionResetAt: snapshot.primary?.resetsAt,
            weeklyResetAt: weeklyWindow?.resetsAt,
            headline: providerState.headline
        )
    }

    private func geminiHistorySnapshot(
        from result: GeminiUsageClientResult,
        providerState: ProviderState,
        recordedAt: Date
    ) -> ProviderHistorySnapshot {
        let primaryBucket = result.primaryBucket
        return ProviderHistorySnapshot(
            accountId: Self.geminiAccountId,
            recordedAt: recordedAt,
            providerId: .gemini,
            confidence: providerState.confidence,
            weeklyUtilizationPercent: primaryBucket?.usedPercent,
            weeklyResetAt: primaryBucket?.resetsAt,
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

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))%"
        }

        return String(format: "%.1f%%", value)
    }

    private static func formatDecimal(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return String(Int(rounded))
        }

        return String(format: "%.4f", value)
    }

    private static func formatCodexWindow(_ window: CodexRateLimitWindow) -> String {
        [
            String(window.usedPercent),
            window.windowDurationMinutes.map(String.init) ?? "unknown",
            window.resetsAt.map { ISO8601DateFormatter.pitwallAppSupport.string(from: $0) } ?? "unknown"
        ].joined(separator: "|")
    }

    private static func displayPlanType(_ planType: String?) -> String? {
        guard let planType else { return nil }

        switch planType {
        case "free":
            return "Free"
        case "go":
            return "Go"
        case "plus":
            return "Plus"
        case "pro":
            return "Pro"
        case "prolite":
            return "Pro Lite"
        case "team":
            return "Team"
        case "business", "self_serve_business_usage_based":
            return "Business"
        case "enterprise", "enterprise_cbp_usage_based":
            return "Enterprise"
        case "edu":
            return "Edu"
        case "unknown":
            return nil
        default:
            return planType
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
