import Foundation
import PitwallCore
import PitwallShared

/// Portable, AppKit-free formatter used by the Linux tray and provider cards.
/// Mirrors the behavior of `MenuBarStatusFormatter` in `PitwallAppSupport` but
/// lives in the Linux shell so it can evolve independently per the
/// cross-platform architecture doc.
public struct LinuxStatusFormatter: Sendable {
    public init() {}

    public func compactTooltip(
        provider: ProviderState,
        preferences: UserPreferences,
        now: Date
    ) -> String {
        if provider.status == .missingConfiguration {
            return "\(provider.displayName) — configure"
        }

        let components = [
            provider.displayName,
            metric(for: provider),
            resetText(
                resetWindow: provider.resetWindow,
                preference: preferences.resetDisplayPreference,
                now: now
            ),
            recommendedActionText(for: provider)
        ]

        return components
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " — ")
    }

    public func metric(for provider: ProviderState) -> String? {
        if let weekly = provider.pacingState?.weeklyUtilizationPercent {
            return Self.formatPercent(weekly)
        }

        if let primary = provider.primaryValue, !primary.isEmpty {
            return primary
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

    public func resetText(
        resetWindow: ResetWindow?,
        preference: ResetDisplayPreference,
        now: Date
    ) -> String? {
        guard let resetsAt = resetWindow?.resetsAt else {
            return nil
        }

        switch preference {
        case .countdown:
            return Self.countdownText(to: resetsAt, now: now)
        case .resetTime:
            return "resets \(Self.timeText(resetsAt))"
        }
    }

    public func recommendedActionText(for provider: ProviderState) -> String? {
        let action = recommendedAction(for: provider)
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

    public func statusText(_ status: ProviderStatus) -> String {
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

    public func confidenceText(_ confidence: ConfidenceLabel) -> String {
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
