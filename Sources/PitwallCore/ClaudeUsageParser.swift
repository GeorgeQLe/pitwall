import Foundation

public struct ClaudeUsageParser: Sendable {
    private static let knownUsageSections: [(key: String, label: String)] = [
        ("five_hour", "Session"),
        ("seven_day", "Weekly"),
        ("seven_day_sonnet", "Sonnet"),
        ("seven_day_opus", "Opus"),
        ("seven_day_oauth_apps", "OAuth apps"),
        ("seven_day_cowork", "Cowork")
    ]

    private static let knownUsageKeys = Set(knownUsageSections.map(\.key))
    private static let extraUsageKey = "extra_usage"

    public init() {}

    public func parse(_ data: Data) throws -> ClaudeUsageResponse {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Claude usage response must be a JSON object."
            ))
        }

        let sections = Self.knownUsageSections.compactMap { section -> ClaudeUsageSection? in
            guard
                let value = object[section.key],
                !(value is NSNull),
                let sectionObject = value as? [String: Any],
                let utilization = sectionObject["utilization"] as? Double
            else {
                return nil
            }

            return ClaudeUsageSection(
                key: section.key,
                label: section.label,
                utilizationPercent: utilization,
                resetsAt: Self.parseDate(sectionObject["resets_at"])
            )
        }

        let extraUsage = decodeExtraUsage(from: object[Self.extraUsageKey])
        let knownKeys = Self.knownUsageKeys.union([Self.extraUsageKey])
        let unknownSectionKeys = Set(object.keys.filter { !knownKeys.contains($0) })

        return ClaudeUsageResponse(
            sections: sections,
            unknownSectionKeys: unknownSectionKeys,
            extraUsage: extraUsage
        )
    }

    public static func normalizedErrorState(
        for reason: ClaudeUsageErrorReason,
        account: ClaudeAccountMetadata,
        lastSuccessfulSnapshot: ClaudeUsageSnapshot?,
        now: Date
    ) -> ProviderState {
        let payload = ProviderSpecificPayload(
            source: "claude",
            values: [
                "accountId": account.id,
                "accountLabel": account.label,
                "organizationId": account.organizationId,
                "errorReason": reason.payloadValue
            ]
        )

        switch reason {
        case .httpStatus(401), .httpStatus(403):
            return ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .expired,
                confidence: .observedOnly,
                headline: "Claude credentials expired",
                secondaryValue: account.label,
                lastUpdatedAt: account.lastSuccessfulRefreshAt,
                confidenceExplanation: "Claude auth failed; only non-secret account metadata is available.",
                actions: [
                    ProviderAction(kind: .openSettings, title: "Replace credentials"),
                    ProviderAction(kind: .testConnection, title: "Test connection", isEnabled: false)
                ],
                payloads: [payload]
            )

        default:
            return staleState(
                reason: reason,
                account: account,
                lastSuccessfulSnapshot: lastSuccessfulSnapshot,
                now: now,
                payload: payload
            )
        }
    }

    private func decodeExtraUsage(from value: Any?) -> ClaudeExtraUsage? {
        guard
            let value,
            !(value is NSNull),
            let object = value as? [String: Any],
            let isEnabled = object["is_enabled"] as? Bool
        else {
            return nil
        }

        return ClaudeExtraUsage(
            isEnabled: isEnabled,
            monthlyLimit: object["monthly_limit"] as? Double ?? 0,
            usedCredits: object["used_credits"] as? Double ?? 0,
            utilizationPercent: object["utilization"] as? Double ?? 0
        )
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let rawValue = value as? String else {
            return nil
        }

        return ISO8601DateFormatter.pitwallClaude.date(from: rawValue)
            ?? ISO8601DateFormatter.pitwallClaudeWithoutFractionalSeconds.date(from: rawValue)
    }

    private static func staleState(
        reason: ClaudeUsageErrorReason,
        account: ClaudeAccountMetadata,
        lastSuccessfulSnapshot: ClaudeUsageSnapshot?,
        now: Date,
        payload: ProviderSpecificPayload
    ) -> ProviderState {
        let lastUpdatedAt = lastSuccessfulSnapshot?.recordedAt ?? account.lastSuccessfulRefreshAt
        let weeklyUtilization = lastSuccessfulSnapshot?.weeklyUtilizationPercent

        return ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .stale,
            confidence: .estimated,
            headline: "Claude usage is stale",
            primaryValue: weeklyUtilization.map(Self.formatPercent),
            secondaryValue: account.label,
            resetWindow: ResetWindow(resetsAt: lastSuccessfulSnapshot?.weeklyResetAt),
            lastUpdatedAt: lastUpdatedAt,
            pacingState: weeklyUtilization.map { utilization in
                PacingState(weeklyUtilizationPercent: utilization)
            },
            confidenceExplanation: "Claude could not refresh at \(Self.formatDate(now)); showing the last successful non-secret snapshot.",
            actions: [
                ProviderAction(kind: .refresh, title: "Refresh now"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: [payload]
        )
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return "\(Int(rounded))%"
        }

        return "\(value)%"
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter.pitwallClaude.string(from: date)
    }
}

private extension ClaudeUsageErrorReason {
    var payloadValue: String {
        switch self {
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

private extension ISO8601DateFormatter {
    static let pitwallClaude: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let pitwallClaudeWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
