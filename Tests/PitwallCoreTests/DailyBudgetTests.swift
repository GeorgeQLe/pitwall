import XCTest
@testable import PitwallCore

final class DailyBudgetTests: XCTestCase {
    private let calculator = PacingCalculator()

    func testDailyBudgetUsesFractionalDaysRemaining() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = now.addingTimeInterval(36 * 60 * 60)

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 70.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: []
        )

        XCTAssertEqual(result.remainingUtilizationPercent, 30.0, accuracy: 0.001)
        XCTAssertEqual(result.daysRemaining, 1.5, accuracy: 0.001)
        XCTAssertEqual(result.dailyBudgetPercent, 20.0, accuracy: 0.001)
        XCTAssertEqual(result.todayUsage.status, .unknown)
        XCTAssertNil(result.todayUsage.utilizationDeltaPercent)
    }

    func testDailyBudgetClampsNearResetToOneHourMinimum() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = now.addingTimeInterval(30 * 60)

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 88.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: []
        )

        XCTAssertEqual(result.daysRemaining, 1.0 / 24.0, accuracy: 0.001)
        XCTAssertEqual(result.dailyBudgetPercent, 288.0, accuracy: 0.001)
    }

    func testTodayUsageUsesClosestSnapshotBeforeLocalMidnight() {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_064_800)
        let resetAt = now.addingTimeInterval(2 * 24 * 60 * 60)

        let snapshots = [
            UsageSnapshot(
                recordedAt: Date(timeIntervalSince1970: 1_800_046_800),
                weeklyUtilizationPercent: 38.0
            ),
            UsageSnapshot(
                recordedAt: Date(timeIntervalSince1970: 1_800_054_000),
                weeklyUtilizationPercent: 42.0
            ),
            UsageSnapshot(
                recordedAt: Date(timeIntervalSince1970: 1_800_061_200),
                weeklyUtilizationPercent: 45.0
            )
        ]

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 54.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: snapshots,
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(result.todayUsage.status, .exact)
        XCTAssertEqual(result.todayUsage.utilizationDeltaPercent ?? 0, 12.0, accuracy: 0.001)
        XCTAssertEqual(result.todayUsage.baselineRecordedAt, Date(timeIntervalSince1970: 1_800_054_000))
    }

    func testTodayUsageFallsBackToEarliestSameDaySnapshot() {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_064_800)
        let resetAt = now.addingTimeInterval(2 * 24 * 60 * 60)

        let snapshots = [
            UsageSnapshot(
                recordedAt: Date(timeIntervalSince1970: 1_800_061_200),
                weeklyUtilizationPercent: 45.0
            ),
            UsageSnapshot(
                recordedAt: Date(timeIntervalSince1970: 1_800_063_000),
                weeklyUtilizationPercent: 49.0
            )
        ]

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 54.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: snapshots,
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(result.todayUsage.status, .estimatedFromSameDayBaseline)
        XCTAssertEqual(result.todayUsage.utilizationDeltaPercent ?? 0, 9.0, accuracy: 0.001)
        XCTAssertEqual(result.todayUsage.baselineRecordedAt, Date(timeIntervalSince1970: 1_800_061_200))
    }

    func testTodayUsageUsesClosestRetainedSnapshotBeforeLocalMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 29,
            hour: 12
        ))!
        let resetAt = now.addingTimeInterval(2 * 24 * 60 * 60)
        let olderPreMidnight = calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 27,
            hour: 23,
            minute: 30
        ))!

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 54.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: [
                UsageSnapshot(
                    recordedAt: olderPreMidnight,
                    weeklyUtilizationPercent: 40.0
                )
            ],
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(result.todayUsage.status, .exact)
        XCTAssertEqual(result.todayUsage.utilizationDeltaPercent ?? 0, 14.0, accuracy: 0.001)
        XCTAssertEqual(result.todayUsage.baselineRecordedAt, olderPreMidnight)
    }

    func testTodayUsageIsUnknownWhenNoBaselineExists() {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_064_800)
        let resetAt = now.addingTimeInterval(2 * 24 * 60 * 60)

        let result = calculator.dailyBudget(
            weeklyUtilizationPercent: 54.0,
            resetAt: resetAt,
            now: now,
            retainedSnapshots: [],
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(result.todayUsage.status, .unknown)
        XCTAssertNil(result.todayUsage.utilizationDeltaPercent)
        XCTAssertNil(result.todayUsage.baselineRecordedAt)
    }
}
