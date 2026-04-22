import XCTest
@testable import PitwallCore

final class HistoryRetentionTests: XCTestCase {
    func testRetainsAllSnapshotsFromLast24Hours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshots = [
            historySnapshot(hoursAgo: 23.75, session: 21, weekly: 43, now: now),
            historySnapshot(hoursAgo: 12, session: 28, weekly: 48, now: now),
            historySnapshot(hoursAgo: 0.25, session: 35, weekly: 51, now: now)
        ]

        let retained = ProviderHistoryRetention(now: now).retainedSnapshots(from: snapshots)

        XCTAssertEqual(retained.map(\.recordedAt), snapshots.map(\.recordedAt))
    }

    func testDownsamplesSnapshotsBetween24HoursAnd7DaysToHourlyBuckets() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let bucketStart = now.addingTimeInterval(-49 * 60 * 60)
        let earlyLowSession = historySnapshot(recordedAt: bucketStart.addingTimeInterval(5 * 60), session: 14, weekly: 40)
        let middleHighestSession = historySnapshot(recordedAt: bucketStart.addingTimeInterval(20 * 60), session: 91, weekly: 41)
        let latestWeekly = historySnapshot(recordedAt: bucketStart.addingTimeInterval(50 * 60), session: 42, weekly: 47)
        let nextBucket = historySnapshot(recordedAt: bucketStart.addingTimeInterval(65 * 60), session: 25, weekly: 48)

        let retained = ProviderHistoryRetention(now: now).retainedSnapshots(from: [
            earlyLowSession,
            middleHighestSession,
            latestWeekly,
            nextBucket
        ])

        XCTAssertEqual(retained.count, 2)
        XCTAssertEqual(retained[0].sessionUtilizationPercent, 91)
        XCTAssertEqual(retained[0].weeklyUtilizationPercent, 47)
        XCTAssertEqual(retained[0].recordedAt, latestWeekly.recordedAt)
        XCTAssertEqual(retained[1], nextBucket)
    }

    func testDropsSnapshotsOlderThan7Days() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let retainedSnapshot = historySnapshot(hoursAgo: 7 * 24 - 0.5, session: 32, weekly: 73, now: now)
        let expiredSnapshot = historySnapshot(hoursAgo: 7 * 24 + 0.5, session: 45, weekly: 88, now: now)

        let retained = ProviderHistoryRetention(now: now).retainedSnapshots(from: [
            retainedSnapshot,
            expiredSnapshot
        ])

        XCTAssertEqual(retained, [retainedSnapshot])
    }

    func testHistorySnapshotsStoreDerivedFieldsOnly() {
        let snapshot = ProviderHistorySnapshot(
            accountId: "acct_1",
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
            providerId: .claude,
            confidence: .exact,
            sessionUtilizationPercent: 33,
            weeklyUtilizationPercent: 52,
            sessionResetAt: Date(timeIntervalSince1970: 1_800_003_600),
            weeklyResetAt: Date(timeIntervalSince1970: 1_800_604_800),
            headline: "Weekly 52%"
        )

        let serialized = String(describing: snapshot)

        XCTAssertFalse(serialized.contains("prompt"))
        XCTAssertFalse(serialized.contains("model response"))
        XCTAssertFalse(serialized.contains("sessionKey"))
        XCTAssertFalse(serialized.contains("cookie"))
        XCTAssertFalse(serialized.contains("authorization"))
        XCTAssertFalse(serialized.contains("raw"))
    }

    private func historySnapshot(
        hoursAgo: Double,
        session: Double,
        weekly: Double,
        now: Date
    ) -> ProviderHistorySnapshot {
        historySnapshot(
            recordedAt: now.addingTimeInterval(-hoursAgo * 60 * 60),
            session: session,
            weekly: weekly
        )
    }

    private func historySnapshot(
        recordedAt: Date,
        session: Double,
        weekly: Double
    ) -> ProviderHistorySnapshot {
        ProviderHistorySnapshot(
            accountId: "acct_1",
            recordedAt: recordedAt,
            providerId: .claude,
            confidence: .exact,
            sessionUtilizationPercent: session,
            weeklyUtilizationPercent: weekly,
            sessionResetAt: recordedAt.addingTimeInterval(2 * 60 * 60),
            weeklyResetAt: recordedAt.addingTimeInterval(5 * 24 * 60 * 60),
            headline: "Weekly \(weekly)%"
        )
    }
}
