import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallWindows

private final class SpyBackend: WindowsToastDelivering, @unchecked Sendable {
    var delivered: [NotificationRequest] = []
    func deliver(_ request: NotificationRequest) {
        delivered.append(request)
    }
}

final class WindowsNotificationSchedulerTests: XCTestCase {
    func test_schedule_forwardsRequestToBackend() {
        let backend = SpyBackend()
        let scheduler = WindowsNotificationScheduler(backend: backend)
        let request = NotificationRequest(
            kind: .reset,
            providerId: .claude,
            accountId: "acct-1",
            title: "Claude session reset",
            body: "Usage window reset is available.",
            createdAt: Date()
        )

        scheduler.schedule(request)

        XCTAssertEqual(backend.delivered.count, 1)
        XCTAssertEqual(backend.delivered.first?.kind, .reset)
        XCTAssertEqual(scheduler.recordedRequests().count, 1)
    }

    func test_notificationPolicy_delegatesThroughWindowsScheduler() {
        let backend = SpyBackend()
        let scheduler = WindowsNotificationScheduler(backend: backend)
        let policy = NotificationPolicy(
            preferences: NotificationPreferences(),
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        policy.handle(
            .reset(
                providerId: .claude,
                accountId: "acct-1",
                resetAt: Date(timeIntervalSince1970: 5_000)
            )
        )

        XCTAssertEqual(backend.delivered.first?.title, "Claude session reset")
        XCTAssertEqual(backend.delivered.first?.kind, .reset)
    }

    func test_suppressedBackend_silentlyAcceptsDelivery() {
        let scheduler = WindowsNotificationScheduler(backend: WindowsToastSuppressedBackend())
        scheduler.schedule(
            NotificationRequest(
                kind: .expiredAuth,
                providerId: .claude,
                title: "t",
                body: "b",
                createdAt: Date()
            )
        )
        XCTAssertEqual(scheduler.recordedRequests().count, 1)
    }
}
