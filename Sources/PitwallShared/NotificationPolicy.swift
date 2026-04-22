import Foundation
import PitwallCore

public enum NotificationKind: String, Equatable, Sendable {
    case reset
    case expiredAuth
    case telemetryDegraded
    case pacingThreshold
}

public enum NotificationEvent: Equatable, Sendable {
    case reset(providerId: ProviderID, accountId: String?, resetAt: Date)
    case expiredAuth(providerId: ProviderID, accountId: String?)
    case telemetryDegraded(providerId: ProviderID, reason: String)
    case pacingThreshold(providerId: ProviderID, label: PacingLabel, utilizationPercent: Double)
}

public struct NotificationRequest: Equatable, Sendable {
    public var kind: NotificationKind
    public var providerId: ProviderID
    public var accountId: String?
    public var title: String
    public var body: String
    public var createdAt: Date
    public var deliverAt: Date?

    public init(
        kind: NotificationKind,
        providerId: ProviderID,
        accountId: String? = nil,
        title: String,
        body: String,
        createdAt: Date,
        deliverAt: Date? = nil
    ) {
        self.kind = kind
        self.providerId = providerId
        self.accountId = accountId
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.deliverAt = deliverAt
    }
}

public protocol NotificationScheduling: AnyObject {
    func schedule(_ request: NotificationRequest)
}

public final class NotificationPolicy {
    private let preferences: NotificationPreferences
    private let scheduler: NotificationScheduling
    private let now: @Sendable () -> Date

    public init(
        preferences: NotificationPreferences,
        scheduler: NotificationScheduling,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.preferences = preferences
        self.scheduler = scheduler
        self.now = now
    }

    public func handle(_ event: NotificationEvent) {
        guard let request = request(for: event) else {
            return
        }

        scheduler.schedule(request)
    }

    private func request(for event: NotificationEvent) -> NotificationRequest? {
        let createdAt = now()

        switch event {
        case let .reset(providerId, accountId, resetAt):
            guard preferences.resetNotificationsEnabled else {
                return nil
            }

            return NotificationRequest(
                kind: .reset,
                providerId: providerId,
                accountId: accountId,
                title: "\(providerName(providerId)) session reset",
                body: "Usage window reset is available.",
                createdAt: createdAt,
                deliverAt: resetAt
            )

        case let .expiredAuth(providerId, accountId):
            guard preferences.expiredAuthNotificationsEnabled else {
                return nil
            }

            return NotificationRequest(
                kind: .expiredAuth,
                providerId: providerId,
                accountId: accountId,
                title: "\(providerName(providerId)) auth expired",
                body: "Reconnect this provider to restore exact telemetry.",
                createdAt: createdAt
            )

        case let .telemetryDegraded(providerId, reason):
            guard preferences.telemetryDegradedNotificationsEnabled else {
                return nil
            }

            return NotificationRequest(
                kind: .telemetryDegraded,
                providerId: providerId,
                title: "\(providerName(providerId)) telemetry degraded",
                body: reason,
                createdAt: createdAt
            )

        case let .pacingThreshold(providerId, label, utilizationPercent):
            guard
                preferences.pacingThresholdNotificationsEnabled,
                label.isAtOrAboveNotificationThreshold(preferences.pacingThreshold)
            else {
                return nil
            }

            return NotificationRequest(
                kind: .pacingThreshold,
                providerId: providerId,
                title: "\(providerName(providerId)) pacing threshold",
                body: "\(Int(utilizationPercent.rounded()))% used, now \(label.displayName.lowercased()).",
                createdAt: createdAt
            )
        }
    }

    private func providerName(_ providerId: ProviderID) -> String {
        switch providerId {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .gemini:
            return "Gemini"
        default:
            return providerId.rawValue.capitalized
        }
    }
}

private extension PacingLabel {
    var notificationRank: Int {
        switch self {
        case .underusing, .behindPace, .onPace, .aheadOfPace, .notEnoughWindow:
            return 0
        case .warning:
            return 1
        case .critical:
            return 2
        case .capped:
            return 3
        }
    }

    var displayName: String {
        switch self {
        case .underusing:
            return "Underusing"
        case .behindPace:
            return "Behind pace"
        case .onPace:
            return "On pace"
        case .aheadOfPace:
            return "Ahead of pace"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        case .capped:
            return "Capped"
        case .notEnoughWindow:
            return "Not enough window"
        }
    }

    func isAtOrAboveNotificationThreshold(_ threshold: PacingLabel) -> Bool {
        notificationRank > 0 && notificationRank >= threshold.notificationRank
    }
}
