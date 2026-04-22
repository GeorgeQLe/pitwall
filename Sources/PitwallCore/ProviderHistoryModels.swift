import Foundation

public struct ProviderHistorySnapshot: Equatable, Sendable, CustomStringConvertible {
    public var accountId: String
    public var recordedAt: Date
    public var providerId: ProviderID
    public var confidence: ConfidenceLabel
    public var sessionUtilizationPercent: Double?
    public var weeklyUtilizationPercent: Double?
    public var sessionResetAt: Date?
    public var weeklyResetAt: Date?
    public var headline: String

    public init(
        accountId: String,
        recordedAt: Date,
        providerId: ProviderID,
        confidence: ConfidenceLabel,
        sessionUtilizationPercent: Double? = nil,
        weeklyUtilizationPercent: Double? = nil,
        sessionResetAt: Date? = nil,
        weeklyResetAt: Date? = nil,
        headline: String
    ) {
        self.accountId = accountId
        self.recordedAt = recordedAt
        self.providerId = providerId
        self.confidence = confidence
        self.sessionUtilizationPercent = sessionUtilizationPercent
        self.weeklyUtilizationPercent = weeklyUtilizationPercent
        self.sessionResetAt = sessionResetAt
        self.weeklyResetAt = weeklyResetAt
        self.headline = headline
    }

    public var description: String {
        [
            "ProviderHistorySnapshot(",
            "accountId: \(accountId), ",
            "recordedAt: \(recordedAt), ",
            "providerId: \(providerId.rawValue), ",
            "confidence: \(confidence.rawValue), ",
            "sessionUtilizationPercent: \(optionalDescription(sessionUtilizationPercent)), ",
            "weeklyUtilizationPercent: \(optionalDescription(weeklyUtilizationPercent)), ",
            "sessionResetAt: \(optionalDescription(sessionResetAt)), ",
            "weeklyResetAt: \(optionalDescription(weeklyResetAt)), ",
            "headline: \(headline)",
            ")"
        ].joined()
    }

    private func optionalDescription(_ value: some CustomStringConvertible) -> String {
        value.description
    }

    private func optionalDescription(_ value: (some CustomStringConvertible)?) -> String {
        value?.description ?? "nil"
    }
}

extension ProviderHistorySnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountId
        case recordedAt
        case providerId
        case confidence
        case sessionUtilizationPercent
        case weeklyUtilizationPercent
        case sessionResetAt
        case weeklyResetAt
        case headline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decode(String.self, forKey: .accountId)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        providerId = ProviderID(rawValue: try container.decode(String.self, forKey: .providerId))
        confidence = ConfidenceLabel(
            rawValue: try container.decode(String.self, forKey: .confidence)
        ) ?? .observedOnly
        sessionUtilizationPercent = try container.decodeIfPresent(
            Double.self,
            forKey: .sessionUtilizationPercent
        )
        weeklyUtilizationPercent = try container.decodeIfPresent(
            Double.self,
            forKey: .weeklyUtilizationPercent
        )
        sessionResetAt = try container.decodeIfPresent(Date.self, forKey: .sessionResetAt)
        weeklyResetAt = try container.decodeIfPresent(Date.self, forKey: .weeklyResetAt)
        headline = try container.decode(String.self, forKey: .headline)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(recordedAt, forKey: .recordedAt)
        try container.encode(providerId.rawValue, forKey: .providerId)
        try container.encode(confidence.rawValue, forKey: .confidence)
        try container.encodeIfPresent(
            sessionUtilizationPercent,
            forKey: .sessionUtilizationPercent
        )
        try container.encodeIfPresent(
            weeklyUtilizationPercent,
            forKey: .weeklyUtilizationPercent
        )
        try container.encodeIfPresent(sessionResetAt, forKey: .sessionResetAt)
        try container.encodeIfPresent(weeklyResetAt, forKey: .weeklyResetAt)
        try container.encode(headline, forKey: .headline)
    }
}
