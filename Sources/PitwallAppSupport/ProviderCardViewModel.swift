import Foundation
import PitwallCore
import PitwallShared

public struct ProviderCardViewModel: Equatable, Sendable {
    public var providerId: ProviderID
    public var displayName: String
    public var headline: String
    public var statusText: String
    public var confidenceText: String
    public var confidenceExplanation: String
    public var primaryMetric: String?
    public var secondaryMetric: String?
    public var resetText: String?
    public var lastUpdatedText: String
    public var recommendedActionText: String
    public var actionReasonText: String?
    public var badges: [String]
    public var actions: [ProviderAction]

    public init(
        provider: ProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) {
        self.providerId = provider.providerId
        self.displayName = provider.displayName
        self.headline = provider.headline
        self.statusText = ProviderDisplayText.status(provider.status)
        self.confidenceText = ProviderDisplayText.confidence(provider.confidence)
        self.confidenceExplanation = provider.confidenceExplanation
        self.primaryMetric = Self.primaryMetric(for: provider)
        self.secondaryMetric = Self.secondaryMetric(for: provider)
        self.resetText = MenuBarStatusFormatter.resetText(
            resetWindow: provider.resetWindow,
            preference: preferences.resetDisplayPreference,
            now: now
        )
        self.lastUpdatedText = Self.lastUpdatedText(provider.lastUpdatedAt, now: now)
        self.recommendedActionText = ProviderDisplayText.action(Self.recommendedAction(for: provider))
        self.actionReasonText = Self.actionReasonText(for: provider)
        self.badges = Self.badges(for: provider)
        self.actions = provider.actions
    }

    private static func primaryMetric(for provider: ProviderState) -> String? {
        let sessionPercent = provider.sessionUtilizationPercent
        let weeklyPercent = provider.pacingState?.weeklyUtilizationPercent

        if sessionPercent != nil || weeklyPercent != nil {
            var parts: [String] = []
            if let s = sessionPercent {
                parts.append("S:\(formatPercent(100 - s))")
            }
            if let w = weeklyPercent {
                parts.append("W:\(formatPercent(100 - w))")
            }
            return parts.joined(separator: " ")
        }

        if let primaryValue = provider.primaryValue, !primaryValue.isEmpty {
            return primaryValue
        }

        return nil
    }

    private static func secondaryMetric(for provider: ProviderState) -> String? {
        if let secondaryValue = provider.secondaryValue, !secondaryValue.isEmpty {
            return secondaryValue
        }

        if let dailyBudget = provider.pacingState?.dailyBudget {
            let budget = Self.formatPercent(dailyBudget.dailyBudgetPercent)
            let days = Self.formatDays(dailyBudget.daysRemaining)
            return "\(budget)/day for \(days)"
        }

        return nil
    }

    private static func recommendedAction(for provider: ProviderState) -> RecommendedAction {
        if provider.status == .missingConfiguration {
            return .configure
        }

        if let weeklyAction = provider.pacingState?.weeklyPace?.action {
            return weeklyAction
        }

        if provider.status == .expired {
            return .configure
        }

        if provider.status == .degraded || provider.status == .stale {
            return .configure
        }

        return provider.actions.first?.recommendedActionFallback ?? .configure
    }

    private static func badges(for provider: ProviderState) -> [String] {
        switch provider.status {
        case .configured:
            return []
        case .missingConfiguration:
            return ["Missing setup"]
        case .stale:
            return ["Stale"]
        case .degraded:
            return ["Degraded"]
        case .expired:
            return ["Expired"]
        }
    }

    private static func actionReasonText(for provider: ProviderState) -> String? {
        guard let pacing = provider.pacingState else {
            return nil
        }

        var clauses: [String] = []

        if let weeklyUtilization = pacing.weeklyUtilizationPercent,
           let weeklyPace = pacing.weeklyPace,
           let expected = weeklyPace.expectedUtilizationPercent {
            let delta = weeklyUtilization - expected
            let direction = delta >= 0 ? "ahead" : "under"
            clauses.append(
                "Used \(formatPercent(weeklyUtilization)) vs \(formatPercent(expected)) expected by now, \(formatPoints(abs(delta))) pts \(direction) pace."
            )
        } else if let weeklyUtilization = pacing.weeklyUtilizationPercent {
            clauses.append("Used \(formatPercent(weeklyUtilization)) this week.")
        }

        if let dailyBudget = pacing.dailyBudget {
            clauses.append(
                "\(formatPercent(dailyBudget.remainingUtilizationPercent)) remains, with \(formatPercent(dailyBudget.dailyBudgetPercent))/day for \(formatDays(dailyBudget.daysRemaining))."
            )
        }

        if let todayUsage = pacing.todayUsage,
           let todayDelta = todayUsage.utilizationDeltaPercent {
            let prefix: String
            switch todayUsage.status {
            case .exact:
                prefix = "Today"
            case .estimatedFromSameDayBaseline:
                prefix = "Today est."
            case .unknown:
                prefix = ""
            }

            if !prefix.isEmpty {
                clauses.append("\(prefix): \(formatPercent(todayDelta)) used.")
            }
        }

        return clauses.isEmpty ? nil : clauses.joined(separator: " ")
    }

    private static func lastUpdatedText(_ date: Date?, now: Date) -> String {
        guard let date else {
            return "Not updated"
        }

        if date > now {
            return "Updated just now"
        }

        let seconds = now.timeIntervalSince(date)
        if seconds < 60 {
            return "Updated just now"
        }

        if seconds < 60 * 60 {
            let minutes = Int(seconds / 60)
            return "Updated \(minutes)m ago"
        }

        if seconds < 24 * 60 * 60 {
            let hours = Int(seconds / (60 * 60))
            return "Updated \(hours)h ago"
        }

        let days = Int(seconds / (24 * 60 * 60))
        return "Updated \(days)d ago"
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))%"
        }

        return String(format: "%.1f%%", value)
    }

    private static func formatDays(_ value: Double) -> String {
        if value < 1 {
            let hours = max(1, Int((value * 24).rounded()))
            return "\(hours)h"
        }

        return String(format: "%.1fd", value)
    }

    private static func formatPoints(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))"
        }

        return String(format: "%.1f", value)
    }
}

private extension ProviderAction {
    var recommendedActionFallback: RecommendedAction {
        switch kind {
        case .refresh:
            return .push
        case .configure, .testConnection, .openSettings:
            return .configure
        case .wait:
            return .wait
        case .switchProvider:
            return .switchProvider
        }
    }
}
