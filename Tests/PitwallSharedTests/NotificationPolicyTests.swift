import XCTest
import PitwallCore
@testable import PitwallShared

final class NotificationPolicySharedTests: XCTestCase {
    func testSchedulesResetExpiredAuthAndTelemetryNotificationsWhenEnabled() {
        let scheduler = RecordingScheduler()
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
        policy.handle(.expiredAuth(providerId: .codex, accountId: nil))
        policy.handle(.telemetryDegraded(providerId: .gemini, reason: "Repeated failures"))
        policy.handle(.pacingThreshold(providerId: .claude, label: .warning, utilizationPercent: 82))

        XCTAssertEqual(scheduler.requests.map(\.kind), [
            .reset,
            .expiredAuth,
            .telemetryDegraded,
            .pacingThreshold
        ])
    }

    func testSuppressesNotificationsWhenPreferencesDisabled() {
        let scheduler = RecordingScheduler()
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(
                resetNotificationsEnabled: false,
                expiredAuthNotificationsEnabled: false,
                telemetryDegradedNotificationsEnabled: false,
                pacingThresholdNotificationsEnabled: false
            ),
            scheduler: scheduler
        )

        policy.handle(.reset(providerId: .claude, accountId: nil, resetAt: Date()))
        policy.handle(.expiredAuth(providerId: .claude, accountId: nil))
        policy.handle(.telemetryDegraded(providerId: .claude, reason: "x"))
        policy.handle(.pacingThreshold(providerId: .claude, label: .critical, utilizationPercent: 95))

        XCTAssertTrue(scheduler.requests.isEmpty)
    }

    func testPacingThresholdBelowConfiguredRankIsIgnored() {
        let scheduler = RecordingScheduler()
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(
                pacingThresholdNotificationsEnabled: true,
                pacingThreshold: .critical
            ),
            scheduler: scheduler
        )

        policy.handle(.pacingThreshold(providerId: .claude, label: .warning, utilizationPercent: 80))

        XCTAssertTrue(scheduler.requests.isEmpty)
    }
}

private final class RecordingScheduler: NotificationScheduling {
    var requests: [NotificationRequest] = []

    func schedule(_ request: NotificationRequest) {
        requests.append(request)
    }
}
