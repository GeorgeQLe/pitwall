import Foundation

public struct ClaudeAccountMetadata: Equatable, Sendable {
    public var id: String
    public var label: String
    public var organizationId: String
    public var lastSuccessfulRefreshAt: Date?

    public init(
        id: String,
        label: String,
        organizationId: String,
        lastSuccessfulRefreshAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.organizationId = organizationId
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
    }
}

public struct ClaudeUsageSection: Equatable, Sendable {
    public var key: String
    public var label: String
    public var utilizationPercent: Double
    public var resetsAt: Date?

    public init(
        key: String,
        label: String,
        utilizationPercent: Double,
        resetsAt: Date? = nil
    ) {
        self.key = key
        self.label = label
        self.utilizationPercent = utilizationPercent
        self.resetsAt = resetsAt
    }
}

public struct ClaudeExtraUsage: Equatable, Sendable {
    public var label: String
    public var isEnabled: Bool
    public var monthlyLimit: Double
    public var usedCredits: Double
    public var utilizationPercent: Double

    public init(
        label: String = "Extra usage",
        isEnabled: Bool,
        monthlyLimit: Double,
        usedCredits: Double,
        utilizationPercent: Double
    ) {
        self.label = label
        self.isEnabled = isEnabled
        self.monthlyLimit = monthlyLimit
        self.usedCredits = usedCredits
        self.utilizationPercent = utilizationPercent
    }
}

public struct ClaudeUsageResponse: Equatable, Sendable {
    public var sections: [ClaudeUsageSection]
    public var unknownSectionKeys: Set<String>
    public var extraUsage: ClaudeExtraUsage?

    public init(
        sections: [ClaudeUsageSection],
        unknownSectionKeys: Set<String> = [],
        extraUsage: ClaudeExtraUsage? = nil
    ) {
        self.sections = sections
        self.unknownSectionKeys = unknownSectionKeys
        self.extraUsage = extraUsage
    }
}

public struct ClaudeUsageSnapshot: Equatable, Sendable {
    public var recordedAt: Date
    public var weeklyUtilizationPercent: Double
    public var weeklyResetAt: Date?

    public init(
        recordedAt: Date,
        weeklyUtilizationPercent: Double,
        weeklyResetAt: Date? = nil
    ) {
        self.recordedAt = recordedAt
        self.weeklyUtilizationPercent = weeklyUtilizationPercent
        self.weeklyResetAt = weeklyResetAt
    }
}

public enum ClaudeUsageErrorReason: Equatable, Sendable {
    case httpStatus(Int)
    case networkUnavailable
    case decodingFailed
    case unknown(String)
}
