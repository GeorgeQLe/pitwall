import Foundation

public struct ProviderID: Hashable, Equatable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let claude = ProviderID(rawValue: "claude")
    public static let codex = ProviderID(rawValue: "codex")
    public static let gemini = ProviderID(rawValue: "gemini")
}

public enum ProviderStatus: String, Equatable, Sendable {
    case configured
    case missingConfiguration
    case stale
    case degraded
    case expired
}

public enum ConfidenceLabel: String, Equatable, Sendable {
    case exact
    case providerSupplied
    case highConfidence
    case estimated
    case observedOnly
}

public enum PacingLabel: String, Equatable, Sendable {
    case underusing
    case behindPace
    case onPace
    case aheadOfPace
    case warning
    case critical
    case capped
    case notEnoughWindow
}

public enum RecommendedAction: String, Equatable, Sendable {
    case push
    case conserve
    case switchProvider
    case wait
    case configure
}

public struct ResetWindow: Equatable, Sendable {
    public var startsAt: Date?
    public var resetsAt: Date?

    public init(startsAt: Date? = nil, resetsAt: Date? = nil) {
        self.startsAt = startsAt
        self.resetsAt = resetsAt
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public var recordedAt: Date
    public var weeklyUtilizationPercent: Double

    public init(recordedAt: Date, weeklyUtilizationPercent: Double) {
        self.recordedAt = recordedAt
        self.weeklyUtilizationPercent = weeklyUtilizationPercent
    }
}

public enum TodayUsageStatus: String, Equatable, Sendable {
    case exact
    case estimatedFromSameDayBaseline
    case unknown
}

public struct TodayUsage: Equatable, Sendable {
    public var status: TodayUsageStatus
    public var utilizationDeltaPercent: Double?
    public var baselineRecordedAt: Date?

    public init(
        status: TodayUsageStatus,
        utilizationDeltaPercent: Double? = nil,
        baselineRecordedAt: Date? = nil
    ) {
        self.status = status
        self.utilizationDeltaPercent = utilizationDeltaPercent
        self.baselineRecordedAt = baselineRecordedAt
    }
}

public struct PaceEvaluation: Equatable, Sendable {
    public var label: PacingLabel
    public var action: RecommendedAction
    public var paceRatio: Double?
    public var expectedUtilizationPercent: Double?
    public var remainingWindowDuration: TimeInterval

    public init(
        label: PacingLabel,
        action: RecommendedAction,
        paceRatio: Double? = nil,
        expectedUtilizationPercent: Double? = nil,
        remainingWindowDuration: TimeInterval = 0
    ) {
        self.label = label
        self.action = action
        self.paceRatio = paceRatio
        self.expectedUtilizationPercent = expectedUtilizationPercent
        self.remainingWindowDuration = remainingWindowDuration
    }
}

public struct DailyBudget: Equatable, Sendable {
    public var remainingUtilizationPercent: Double
    public var daysRemaining: Double
    public var dailyBudgetPercent: Double
    public var todayUsage: TodayUsage

    public init(
        remainingUtilizationPercent: Double,
        daysRemaining: Double,
        dailyBudgetPercent: Double,
        todayUsage: TodayUsage
    ) {
        self.remainingUtilizationPercent = remainingUtilizationPercent
        self.daysRemaining = daysRemaining
        self.dailyBudgetPercent = dailyBudgetPercent
        self.todayUsage = todayUsage
    }
}

public struct PacingState: Equatable, Sendable {
    public var weeklyUtilizationPercent: Double?
    public var remainingWindowDuration: TimeInterval?
    public var dailyBudget: DailyBudget?
    public var todayUsage: TodayUsage?
    public var currentBurnRatePercentPerHour: Double?
    public var projectedCapTime: Date?
    public var underUseSignal: Bool
    public var estimatedExtraUsageExposure: Double?
    public var weeklyPace: PaceEvaluation?
    public var sessionPace: PaceEvaluation?

    public init(
        weeklyUtilizationPercent: Double? = nil,
        remainingWindowDuration: TimeInterval? = nil,
        dailyBudget: DailyBudget? = nil,
        todayUsage: TodayUsage? = nil,
        currentBurnRatePercentPerHour: Double? = nil,
        projectedCapTime: Date? = nil,
        underUseSignal: Bool = false,
        estimatedExtraUsageExposure: Double? = nil,
        weeklyPace: PaceEvaluation? = nil,
        sessionPace: PaceEvaluation? = nil
    ) {
        self.weeklyUtilizationPercent = weeklyUtilizationPercent
        self.remainingWindowDuration = remainingWindowDuration
        self.dailyBudget = dailyBudget
        self.todayUsage = todayUsage
        self.currentBurnRatePercentPerHour = currentBurnRatePercentPerHour
        self.projectedCapTime = projectedCapTime
        self.underUseSignal = underUseSignal
        self.estimatedExtraUsageExposure = estimatedExtraUsageExposure
        self.weeklyPace = weeklyPace
        self.sessionPace = sessionPace
    }
}

public struct ProviderSpecificPayload: Equatable, Sendable {
    public var source: String
    public var values: [String: String]

    public init(source: String, values: [String: String] = [:]) {
        self.source = source
        self.values = values
    }
}

public struct ProviderAction: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case refresh
        case configure
        case testConnection
        case openSettings
        case wait
        case switchProvider
    }

    public var kind: Kind
    public var title: String
    public var isEnabled: Bool

    public init(kind: Kind, title: String, isEnabled: Bool = true) {
        self.kind = kind
        self.title = title
        self.isEnabled = isEnabled
    }
}

public struct ProviderState: Equatable, Sendable {
    public var providerId: ProviderID
    public var displayName: String
    public var status: ProviderStatus
    public var confidence: ConfidenceLabel
    public var headline: String
    public var primaryValue: String?
    public var secondaryValue: String?
    public var resetWindow: ResetWindow?
    public var lastUpdatedAt: Date?
    public var pacingState: PacingState?
    public var confidenceExplanation: String
    public var actions: [ProviderAction]
    public var payloads: [ProviderSpecificPayload]

    public init(
        providerId: ProviderID,
        displayName: String,
        status: ProviderStatus,
        confidence: ConfidenceLabel,
        headline: String,
        primaryValue: String? = nil,
        secondaryValue: String? = nil,
        resetWindow: ResetWindow? = nil,
        lastUpdatedAt: Date? = nil,
        pacingState: PacingState? = nil,
        confidenceExplanation: String = "",
        actions: [ProviderAction] = [],
        payloads: [ProviderSpecificPayload] = []
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.status = status
        self.confidence = confidence
        self.headline = headline
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.resetWindow = resetWindow
        self.lastUpdatedAt = lastUpdatedAt
        self.pacingState = pacingState
        self.confidenceExplanation = confidenceExplanation
        self.actions = actions
        self.payloads = payloads
    }
}
