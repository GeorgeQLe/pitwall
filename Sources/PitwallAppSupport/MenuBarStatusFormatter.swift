import Foundation
import PitwallCore

public struct MenuBarStatusFormatter: Sendable {
    public init() {}

    public func format(
        appState: AppProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> String {
        guard let provider = appState.selectedProvider() else {
            return "Pitwall configure"
        }

        return format(provider: provider, preferences: preferences, now: now)
    }

    public func format(
        provider: ProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> String {
        if provider.status == .missingConfiguration {
            return "\(provider.displayName) configure"
        }

        let metric = compactMetric(for: provider)
        let reset = Self.resetText(
            resetWindow: provider.resetWindow,
            preference: preferences.resetDisplayPreference,
            now: now
        )
        let action = ProviderDisplayText.action(recommendedAction(for: provider))

        return [provider.displayName, metric, reset, action]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }

                return value
            }
            .joined(separator: " - ")
    }

    public static func resetText(
        resetWindow: ResetWindow?,
        preference: ResetDisplayPreference,
        now: Date = Date()
    ) -> String? {
        guard let resetsAt = resetWindow?.resetsAt else {
            return nil
        }

        switch preference {
        case .countdown:
            return countdownText(to: resetsAt, now: now)
        case .resetTime:
            return "resets \(timeText(resetsAt))"
        }
    }

    private func compactMetric(for provider: ProviderState) -> String? {
        if let weeklyUtilizationPercent = provider.pacingState?.weeklyUtilizationPercent {
            return Self.formatPercent(weeklyUtilizationPercent)
        }

        if let primaryValue = provider.primaryValue, !primaryValue.isEmpty {
            return primaryValue
        }

        switch provider.confidence {
        case .exact:
            return "exact"
        case .providerSupplied:
            return "provider"
        case .highConfidence:
            return "high"
        case .estimated:
            return "estimated"
        case .observedOnly:
            return "observed"
        }
    }

    private func recommendedAction(for provider: ProviderState) -> RecommendedAction {
        if provider.status == .missingConfiguration || provider.status == .expired {
            return .configure
        }

        if let weeklyAction = provider.pacingState?.weeklyPace?.action {
            return weeklyAction
        }

        if provider.status == .degraded || provider.status == .stale {
            return .configure
        }

        return .configure
    }

    private static func countdownText(to date: Date, now: Date) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        if seconds < 60 {
            return "<1m"
        }

        if seconds < 60 * 60 {
            return "\(Int(seconds / 60))m"
        }

        if seconds < 24 * 60 * 60 {
            let hours = Int(seconds / (60 * 60))
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 60 * 60)) / 60)
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }

        let days = Int(seconds / (24 * 60 * 60))
        let hours = Int((seconds.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))%"
        }

        return String(format: "%.1f%%", value)
    }
}

enum ProviderDisplayText {
    static func status(_ status: ProviderStatus) -> String {
        switch status {
        case .configured:
            return "Configured"
        case .missingConfiguration:
            return "Missing setup"
        case .stale:
            return "Stale"
        case .degraded:
            return "Degraded"
        case .expired:
            return "Expired"
        }
    }

    static func confidence(_ confidence: ConfidenceLabel) -> String {
        switch confidence {
        case .exact:
            return "Exact"
        case .providerSupplied:
            return "Provider supplied"
        case .highConfidence:
            return "High confidence"
        case .estimated:
            return "Estimated"
        case .observedOnly:
            return "Observed only"
        }
    }

    static func action(_ action: RecommendedAction) -> String {
        switch action {
        case .push:
            return "push"
        case .conserve:
            return "conserve"
        case .switchProvider:
            return "switch"
        case .wait:
            return "wait"
        case .configure:
            return "configure"
        }
    }
}
