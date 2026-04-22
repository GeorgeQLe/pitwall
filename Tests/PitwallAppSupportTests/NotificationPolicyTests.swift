import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class NotificationPolicyTests: XCTestCase {
    func testSchedulesResetExpiredAuthTelemetryAndThresholdNotificationsWhenEnabled() {
        let scheduler = RecordingNotificationScheduler()
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(
                resetNotificationsEnabled: true,
                expiredAuthNotificationsEnabled: true,
                telemetryDegradedNotificationsEnabled: true,
                pacingThresholdNotificationsEnabled: true,
                pacingThreshold: .warning
            ),
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        policy.handle(.reset(providerId: .claude, accountId: "acct_1", resetAt: Date(timeIntervalSince1970: 1_800_003_600)))
        policy.handle(.expiredAuth(providerId: .claude, accountId: "acct_1"))
        policy.handle(.telemetryDegraded(providerId: .codex, reason: "Repeated failures"))
        policy.handle(.pacingThreshold(providerId: .claude, label: .warning, utilizationPercent: 82))

        XCTAssertEqual(scheduler.requests.map(\.kind), [
            .reset,
            .expiredAuth,
            .telemetryDegraded,
            .pacingThreshold
        ])
    }

    func testDisabledNotificationPreferencesSuppressAllScheduling() {
        let scheduler = RecordingNotificationScheduler()
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(
                resetNotificationsEnabled: false,
                expiredAuthNotificationsEnabled: false,
                telemetryDegradedNotificationsEnabled: false,
                pacingThresholdNotificationsEnabled: false,
                pacingThreshold: .warning
            ),
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        policy.handle(.reset(providerId: .claude, accountId: "acct_1", resetAt: Date(timeIntervalSince1970: 1_800_003_600)))
        policy.handle(.expiredAuth(providerId: .claude, accountId: "acct_1"))
        policy.handle(.telemetryDegraded(providerId: .codex, reason: "Repeated failures"))
        policy.handle(.pacingThreshold(providerId: .claude, label: .critical, utilizationPercent: 96))

        XCTAssertEqual(scheduler.requests, [])
    }

    func testPacingThresholdOnlySchedulesAtOrAboveConfiguredThreshold() {
        let scheduler = RecordingNotificationScheduler()
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(
                pacingThresholdNotificationsEnabled: true,
                pacingThreshold: .critical
            ),
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        policy.handle(.pacingThreshold(providerId: .claude, label: .warning, utilizationPercent: 82))
        policy.handle(.pacingThreshold(providerId: .claude, label: .critical, utilizationPercent: 96))

        XCTAssertEqual(scheduler.requests.map(\.kind), [.pacingThreshold])
        XCTAssertEqual(scheduler.requests.first?.providerId, .claude)
    }
}

private final class RecordingNotificationScheduler: NotificationScheduling {
    private(set) var requests: [NotificationRequest] = []

    func schedule(_ request: NotificationRequest) {
        requests.append(request)
    }
}
