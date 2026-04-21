import XCTest
@testable import PitwallCore

final class PacingCalculatorTests: XCTestCase {
    private let calculator = PacingCalculator()

    func testWeeklyPaceRatioThresholds() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(7 * 24 * 60 * 60)
        let now = windowStart.addingTimeInterval(4 * 24 * 60 * 60)

        assertWeeklyPace(
            utilization: 20.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 0.35,
            expectedLabel: .underusing,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: 40.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 0.70,
            expectedLabel: .behindPace,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: 60.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.05,
            expectedLabel: .onPace,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: 80.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.40,
            expectedLabel: .aheadOfPace,
            expectedAction: .conserve
        )
        assertWeeklyPace(
            utilization: 100.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.75,
            expectedLabel: .capped,
            expectedAction: .wait
        )
    }

    func testWeeklyWarningCriticalAndCappedThresholds() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(7 * 24 * 60 * 60)
        let now = windowStart.addingTimeInterval(2 * 24 * 60 * 60)

        assertWeeklyPace(
            utilization: 48.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.68,
            expectedLabel: .warning,
            expectedAction: .conserve
        )
        assertWeeklyPace(
            utilization: 60.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 2.10,
            expectedLabel: .critical,
            expectedAction: .wait
        )
        assertWeeklyPace(
            utilization: 101.0,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 3.54,
            expectedLabel: .capped,
            expectedAction: .wait
        )
    }

    func testWeeklyPaceRatioBoundaryLabels() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(7 * 24 * 60 * 60)
        let now = windowStart.addingTimeInterval(2 * 24 * 60 * 60)
        let expectedUtilization = 100.0 * (2.0 / 7.0)

        assertWeeklyPace(
            utilization: expectedUtilization * 0.50,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 0.50,
            expectedLabel: .behindPace,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: expectedUtilization * 0.85,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 0.85,
            expectedLabel: .onPace,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: expectedUtilization * 1.15,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.15,
            expectedLabel: .onPace,
            expectedAction: .push
        )
        assertWeeklyPace(
            utilization: expectedUtilization * 1.50,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 1.50,
            expectedLabel: .aheadOfPace,
            expectedAction: .conserve
        )
        assertWeeklyPace(
            utilization: expectedUtilization * 2.00,
            now: now,
            windowStart: windowStart,
            resetAt: resetAt,
            expectedRatio: 2.00,
            expectedLabel: .warning,
            expectedAction: .conserve
        )
    }

    func testWeeklyPacingIgnoresFirstSixHoursAndLastHour() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(7 * 24 * 60 * 60)

        let earlyResult = calculator.evaluateWeeklyPace(
            utilizationPercent: 3.0,
            windowStart: windowStart,
            resetAt: resetAt,
            now: windowStart.addingTimeInterval((6 * 60 * 60) - 1)
        )
        XCTAssertEqual(earlyResult.label, .notEnoughWindow)
        XCTAssertNil(earlyResult.paceRatio)

        let lateResult = calculator.evaluateWeeklyPace(
            utilizationPercent: 96.0,
            windowStart: windowStart,
            resetAt: resetAt,
            now: resetAt.addingTimeInterval(-(60 * 60) + 1)
        )
        XCTAssertEqual(lateResult.label, .notEnoughWindow)
        XCTAssertNil(lateResult.paceRatio)
    }

    func testSessionPacingIgnoresFirstFifteenMinutesAndLastFiveMinutes() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(5 * 60 * 60)

        let earlyResult = calculator.evaluateSessionPace(
            utilizationPercent: 10.0,
            windowStart: windowStart,
            resetAt: resetAt,
            now: windowStart.addingTimeInterval((15 * 60) - 1)
        )
        XCTAssertEqual(earlyResult.label, .notEnoughWindow)
        XCTAssertNil(earlyResult.paceRatio)

        let lateResult = calculator.evaluateSessionPace(
            utilizationPercent: 95.0,
            windowStart: windowStart,
            resetAt: resetAt,
            now: resetAt.addingTimeInterval(-(5 * 60) + 1)
        )
        XCTAssertEqual(lateResult.label, .notEnoughWindow)
        XCTAssertNil(lateResult.paceRatio)
    }

    func testSessionPaceUsesSameRatioShapeAsWeeklyPace() {
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = windowStart.addingTimeInterval(5 * 60 * 60)
        let now = windowStart.addingTimeInterval(2 * 60 * 60)

        let result = calculator.evaluateSessionPace(
            utilizationPercent: 50.0,
            windowStart: windowStart,
            resetAt: resetAt,
            now: now
        )

        XCTAssertEqual(result.label, .aheadOfPace)
        XCTAssertEqual(result.action, .conserve)
        XCTAssertEqual(result.paceRatio ?? 0, 1.25, accuracy: 0.001)
        XCTAssertEqual(result.expectedUtilizationPercent ?? 0, 40.0, accuracy: 0.001)
    }

    private func assertWeeklyPace(
        utilization: Double,
        now: Date,
        windowStart: Date,
        resetAt: Date,
        expectedRatio: Double,
        expectedLabel: PacingLabel,
        expectedAction: RecommendedAction,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = calculator.evaluateWeeklyPace(
            utilizationPercent: utilization,
            windowStart: windowStart,
            resetAt: resetAt,
            now: now
        )

        XCTAssertEqual(result.label, expectedLabel, file: file, line: line)
        XCTAssertEqual(result.action, expectedAction, file: file, line: line)
        XCTAssertEqual(result.paceRatio ?? 0, expectedRatio, accuracy: 0.01, file: file, line: line)
    }
}
