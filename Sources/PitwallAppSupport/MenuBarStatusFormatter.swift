import Foundation
import PitwallCore
import PitwallShared

public struct MenuBarStatusFormatter: Sendable {
    public init() {}

    public func menuBarTitle(
        appState: AppProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> String {
        guard let provider = appState.selectedProvider(trackedOnly: true) else {
            return "Configure"
        }

        return menuBarTitle(provider: provider, preferences: preferences, now: now)
    }

    public func menuBarTitle(
        provider: ProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> String {
        if let claudeTitle = claudeMenuBarTitle(
            provider: provider,
            preferences: preferences,
            now: now
        ) {
            return claudeTitle
        }

        if provider.status == .missingConfiguration {
            return "\(provider.displayName) configure"
        }

        let metric = compactMetric(for: provider)
        let reset = Self.resetText(
            resetWindow: provider.resetWindow,
            preference: preferences.resetDisplayPreference,
            now: now
        )?.replacingOccurrences(of: "resets ", with: "")
        let action = ProviderDisplayText.action(recommendedAction(for: provider))

        return [provider.displayName, metric, reset, action]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }

                return value
            }
            .joined(separator: " ")
    }

    private func claudeMenuBarTitle(
        provider: ProviderState,
        preferences: UserPreferences,
        now: Date
    ) -> String? {
        guard provider.providerId == .claude, provider.status == .configured else {
            return nil
        }

        let sessionPercent = usageRowPercent(named: "Session", in: provider)
        let weeklyPercent = provider.pacingState?.weeklyUtilizationPercent
        let todayPercent = provider.pacingState?.todayUsage?.utilizationDeltaPercent
        let dailyBudgetPercent = provider.pacingState?.dailyBudget?.dailyBudgetPercent
        let sessionEmoji = preferences.menuBarTheme.emoji(for: sessionStatus(for: provider))
        let weeklyEmoji = preferences.menuBarTheme.emoji(for: weeklyStatus(for: provider))
        let targetEmoji = preferences.menuBarTheme.targetEmoji
        let reset = Self.resetText(
            resetWindow: provider.resetWindow,
            preference: preferences.resetDisplayPreference,
            now: now
        )?.replacingOccurrences(of: "resets ", with: "")

        var parts: [String] = []

        if let sessionPercent {
            parts.append("\(sessionEmoji) \(Self.formatPercent(sessionPercent))")
        }

        if let todayPercent, let dailyBudgetPercent {
            parts.append("\(targetEmoji) \(Self.formatPercent(todayPercent))/\(Self.formatPercent(dailyBudgetPercent))/day")
        } else if let todayPercent {
            parts.append("\(targetEmoji) \(Self.formatPercent(todayPercent))/day")
        } else if let dailyBudgetPercent {
            parts.append("\(targetEmoji) \(Self.formatPercent(dailyBudgetPercent))/day")
        }

        if let weeklyPercent {
            parts.append("\(weeklyEmoji) \(Self.formatPercent(weeklyPercent))/w")
        }

        if let reset, !reset.isEmpty {
            parts.append(reset)
        }

        guard !parts.isEmpty else {
            return nil
        }

        return ([provider.displayName] + parts).joined(separator: " ")
    }

    public func format(
        appState: AppProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> String {
        guard let provider = appState.selectedProvider(trackedOnly: true) else {
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

    private func usageRowPercent(named label: String, in provider: ProviderState) -> Double? {
        guard let payload = provider.payloads.first(where: { $0.source == "usageRows" }),
              let encodedValue = payload.values[label] else {
            return nil
        }

        let parts = encodedValue.split(separator: "|", omittingEmptySubsequences: false)
        guard let percentPart = parts.first, let percent = Double(percentPart) else {
            return nil
        }

        return percent
    }

    private func sessionStatus(for provider: ProviderState) -> MenuBarPaceStatus {
        guard let sessionPercent = usageRowPercent(named: "Session", in: provider) else {
            return .unknown
        }

        if sessionPercent >= 100 {
            return .limitHit
        }

        guard let expected = provider.pacingState?.sessionPace?.expectedUtilizationPercent else {
            if sessionPercent >= 80 {
                return .critical
            }

            if sessionPercent >= 60 {
                return .warning
            }

            return .unknown
        }

        return paceStatus(actual: sessionPercent, expected: expected)
    }

    private func weeklyStatus(for provider: ProviderState) -> MenuBarPaceStatus {
        guard let weeklyPercent = provider.pacingState?.weeklyUtilizationPercent else {
            return .unknown
        }

        if weeklyPercent >= 100 {
            return .limitHit
        }

        guard let expected = provider.pacingState?.weeklyPace?.expectedUtilizationPercent else {
            return .unknown
        }

        return paceStatus(actual: weeklyPercent, expected: expected)
    }

    private func paceStatus(actual: Double, expected: Double) -> MenuBarPaceStatus {
        guard expected > 0 else {
            return .unknown
        }

        let ratio = actual / expected
        if ratio > 1.4 {
            return .critical
        }

        if ratio > 1.15 {
            return .warning
        }

        if ratio < 0.6 {
            return .wayBehind
        }

        if ratio < 0.85 {
            return .behindPace
        }

        return .onTrack
    }
}

private enum MenuBarPaceStatus {
    case unknown
    case onTrack
    case warning
    case critical
    case limitHit
    case behindPace
    case wayBehind
}

private extension MenuBarTheme {
    func emoji(for status: MenuBarPaceStatus) -> String {
        switch self {
        case .running:
            switch status {
            case .unknown, .onTrack:
                return "🚶"
            case .behindPace:
                return "🦥"
            case .wayBehind:
                return "🛌"
            case .warning:
                return "🏃"
            case .critical:
                return "🔥"
            case .limitHit:
                return "💀"
            }
        case .racecar:
            switch status {
            case .unknown, .onTrack:
                return "🏎️"
            case .behindPace:
                return "🚗"
            case .wayBehind:
                return "🅿️"
            case .warning:
                return "🟡"
            case .critical:
                return "🚨"
            case .limitHit:
                return "🔴"
            }
        case .f1Quali:
            switch status {
            case .unknown, .onTrack:
                return "🟣"
            case .behindPace:
                return "🔵"
            case .wayBehind:
                return "⚪"
            case .warning:
                return "🟢"
            case .critical:
                return "🟡"
            case .limitHit:
                return "🔴"
            }
        }
    }

    var targetEmoji: String {
        switch self {
        case .running:
            return "🎯"
        case .racecar:
            return "🏁"
        case .f1Quali:
            return "🎯"
        }
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
