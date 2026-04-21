import Foundation

public enum ProviderConfidenceEvidence: Equatable, Sendable {
    case claudeUsage(refreshedAt: Date, hasCurrentUsage: Bool)
    case codexPassive(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        configuredPlan: String?,
        repeatedLimitSignals: Bool
    )
    case geminiPassive(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        configuredProfile: String?,
        commandSummaryAvailable: Bool
    )
    case telemetryDegraded(providerId: ProviderID, fallbackActivityDetected: Bool, reason: String)
    case missingConfiguration(providerId: ProviderID)
}

public struct ProviderConfidenceResult: Equatable, Sendable {
    public var providerId: ProviderID
    public var label: ConfidenceLabel
    public var providerStatus: ProviderStatus
    public var explanation: String

    public init(
        providerId: ProviderID,
        label: ConfidenceLabel,
        providerStatus: ProviderStatus,
        explanation: String
    ) {
        self.providerId = providerId
        self.label = label
        self.providerStatus = providerStatus
        self.explanation = explanation
    }
}

public struct ProviderConfidenceMapper: Sendable {
    public init() {}

    public func map(_ evidence: ProviderConfidenceEvidence) -> ProviderConfidenceResult {
        switch evidence {
        case let .claudeUsage(refreshedAt, hasCurrentUsage):
            return mapClaudeUsage(refreshedAt: refreshedAt, hasCurrentUsage: hasCurrentUsage)

        case let .codexPassive(installDetected, authDetected, activityDetected, configuredPlan, repeatedLimitSignals):
            return mapCodexPassive(
                installDetected: installDetected,
                authDetected: authDetected,
                activityDetected: activityDetected,
                configuredPlan: configuredPlan,
                repeatedLimitSignals: repeatedLimitSignals
            )

        case let .geminiPassive(installDetected, authDetected, activityDetected, configuredProfile, commandSummaryAvailable):
            return mapGeminiPassive(
                installDetected: installDetected,
                authDetected: authDetected,
                activityDetected: activityDetected,
                configuredProfile: configuredProfile,
                commandSummaryAvailable: commandSummaryAvailable
            )

        case let .telemetryDegraded(providerId, fallbackActivityDetected, reason):
            return mapTelemetryDegraded(
                providerId: providerId,
                fallbackActivityDetected: fallbackActivityDetected,
                reason: reason
            )

        case let .missingConfiguration(providerId):
            return ProviderConfidenceResult(
                providerId: providerId,
                label: .observedOnly,
                providerStatus: .missingConfiguration,
                explanation: "\(Self.displayName(for: providerId)) configuration is required before quota confidence can improve."
            )
        }
    }

    private func mapClaudeUsage(refreshedAt: Date, hasCurrentUsage: Bool) -> ProviderConfidenceResult {
        guard hasCurrentUsage else {
            return ProviderConfidenceResult(
                providerId: .claude,
                label: .observedOnly,
                providerStatus: .missingConfiguration,
                explanation: "Claude usage is unavailable; configuration or a successful refresh is required."
            )
        }

        return ProviderConfidenceResult(
            providerId: .claude,
            label: .exact,
            providerStatus: .configured,
            explanation: "Confidence is exact because fresh Claude usage was refreshed at \(Self.formatDate(refreshedAt))."
        )
    }

    private func mapCodexPassive(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        configuredPlan: String?,
        repeatedLimitSignals: Bool
    ) -> ProviderConfidenceResult {
        let hasQuotaContext = configuredPlan?.isEmpty == false
        let label: ConfidenceLabel
        let explanation: String

        if authDetected, activityDetected, hasQuotaContext, repeatedLimitSignals {
            label = .highConfidence
            explanation = "Confidence is high because Codex auth, plan/profile context, activity, and repeated limit/reset signals are present."
        } else if authDetected, activityDetected, hasQuotaContext {
            label = .estimated
            explanation = "Confidence is estimated from Codex plan/profile context plus passive local activity."
        } else if installDetected || authDetected || activityDetected {
            label = .observedOnly
            explanation = "Only Codex install/auth/activity evidence is available without enough quota context."
        } else {
            label = .observedOnly
            explanation = "Codex evidence is missing; only observed-only confidence can be reported."
        }

        return ProviderConfidenceResult(
            providerId: .codex,
            label: label,
            providerStatus: .configured,
            explanation: explanation
        )
    }

    private func mapGeminiPassive(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        configuredProfile: String?,
        commandSummaryAvailable: Bool
    ) -> ProviderConfidenceResult {
        let hasQuotaContext = configuredProfile?.isEmpty == false
        let label: ConfidenceLabel
        let explanation: String

        if authDetected, hasQuotaContext, activityDetected, commandSummaryAvailable {
            label = .highConfidence
            explanation = "Confidence is high because Gemini auth, profile context, activity, and command summary data are present."
        } else if authDetected, hasQuotaContext, activityDetected {
            label = .estimated
            explanation = "Confidence is estimated from Gemini auth/profile context plus local request activity."
        } else if installDetected || authDetected || activityDetected {
            label = .observedOnly
            explanation = "Only Gemini local activity is available without enough plan/auth confidence."
        } else {
            label = .observedOnly
            explanation = "Gemini evidence is missing; only observed-only confidence can be reported."
        }

        return ProviderConfidenceResult(
            providerId: .gemini,
            label: label,
            providerStatus: .configured,
            explanation: explanation
        )
    }

    private func mapTelemetryDegraded(
        providerId: ProviderID,
        fallbackActivityDetected: Bool,
        reason: String
    ) -> ProviderConfidenceResult {
        let label: ConfidenceLabel = fallbackActivityDetected ? .estimated : .observedOnly
        let fallbackDescription = fallbackActivityDetected ? "falling back to sanitized passive activity" : "no fallback activity available"

        return ProviderConfidenceResult(
            providerId: providerId,
            label: label,
            providerStatus: .degraded,
            explanation: "\(Self.displayName(for: providerId)) telemetry is degraded because \(reason); \(fallbackDescription)."
        )
    }

    private static func displayName(for providerId: ProviderID) -> String {
        switch providerId {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .gemini:
            return "Gemini"
        default:
            return providerId.rawValue
        }
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter.pitwallProviderConfidence.string(from: date)
    }
}

private extension ISO8601DateFormatter {
    static let pitwallProviderConfidence: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
