import Foundation

public struct PacingCalculator: Sendable {
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    public init() {}

    public func evaluateWeeklyPace(
        utilizationPercent: Double,
        windowStart: Date,
        resetAt: Date,
        now: Date
    ) -> PaceEvaluation {
        evaluatePace(
            utilizationPercent: utilizationPercent,
            windowStart: windowStart,
            resetAt: resetAt,
            now: now,
            ignoreAfterStart: 6 * 60 * 60,
            ignoreBeforeReset: 60 * 60
        )
    }

    public func evaluateSessionPace(
        utilizationPercent: Double,
        windowStart: Date,
        resetAt: Date,
        now: Date
    ) -> PaceEvaluation {
        evaluatePace(
            utilizationPercent: utilizationPercent,
            windowStart: windowStart,
            resetAt: resetAt,
            now: now,
            ignoreAfterStart: 15 * 60,
            ignoreBeforeReset: 5 * 60
        )
    }

    public func dailyBudget(
        weeklyUtilizationPercent: Double,
        resetAt: Date,
        now: Date,
        retainedSnapshots: [UsageSnapshot],
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> DailyBudget {
        let remainingUtilizationPercent = max(0, 100 - weeklyUtilizationPercent)
        let rawDaysRemaining = resetAt.timeIntervalSince(now) / Self.secondsPerDay
        let daysRemaining = max(rawDaysRemaining, 1.0 / 24.0)
        let dailyBudgetPercent = remainingUtilizationPercent / daysRemaining

        return DailyBudget(
            remainingUtilizationPercent: remainingUtilizationPercent,
            daysRemaining: daysRemaining,
            dailyBudgetPercent: dailyBudgetPercent,
            todayUsage: todayUsage(
                weeklyUtilizationPercent: weeklyUtilizationPercent,
                now: now,
                retainedSnapshots: retainedSnapshots,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    private func evaluatePace(
        utilizationPercent: Double,
        windowStart: Date,
        resetAt: Date,
        now: Date,
        ignoreAfterStart: TimeInterval,
        ignoreBeforeReset: TimeInterval
    ) -> PaceEvaluation {
        let remainingWindowDuration = max(0, resetAt.timeIntervalSince(now))
        let elapsedDuration = now.timeIntervalSince(windowStart)
        let fullWindowDuration = resetAt.timeIntervalSince(windowStart)

        guard fullWindowDuration > 0,
              elapsedDuration >= ignoreAfterStart,
              remainingWindowDuration >= ignoreBeforeReset else {
            return PaceEvaluation(
                label: .notEnoughWindow,
                action: .configure,
                remainingWindowDuration: remainingWindowDuration
            )
        }

        let elapsedFraction = elapsedDuration / fullWindowDuration
        let expectedUtilizationPercent = elapsedFraction * 100

        guard expectedUtilizationPercent > 0 else {
            return PaceEvaluation(
                label: .notEnoughWindow,
                action: .configure,
                remainingWindowDuration: remainingWindowDuration
            )
        }

        let paceRatio = utilizationPercent / expectedUtilizationPercent
        let mapping = labelAndAction(utilizationPercent: utilizationPercent, paceRatio: paceRatio)

        return PaceEvaluation(
            label: mapping.label,
            action: mapping.action,
            paceRatio: paceRatio,
            expectedUtilizationPercent: expectedUtilizationPercent,
            remainingWindowDuration: remainingWindowDuration
        )
    }

    private func labelAndAction(
        utilizationPercent: Double,
        paceRatio: Double
    ) -> (label: PacingLabel, action: RecommendedAction) {
        if utilizationPercent >= 100 {
            return (.capped, .wait)
        }

        switch paceRatio {
        case ..<0.50:
            return (.underusing, .push)
        case 0.50..<0.85:
            return (.behindPace, .push)
        case 0.85...1.15:
            return (.onPace, .push)
        case 1.15...1.50:
            return (.aheadOfPace, .conserve)
        case 1.50...2.00:
            return (.warning, .conserve)
        default:
            return (.critical, .wait)
        }
    }

    private func todayUsage(
        weeklyUtilizationPercent: Double,
        now: Date,
        retainedSnapshots: [UsageSnapshot],
        calendar: Calendar,
        timeZone: TimeZone
    ) -> TodayUsage {
        var localCalendar = calendar
        localCalendar.timeZone = timeZone

        let startOfToday = localCalendar.startOfDay(for: now)
        let startOfPreviousDay = localCalendar.date(
            byAdding: .day,
            value: -1,
            to: startOfToday
        ) ?? startOfToday.addingTimeInterval(-Self.secondsPerDay)
        let sortedSnapshots = retainedSnapshots.sorted { $0.recordedAt < $1.recordedAt }

        if let baseline = sortedSnapshots.last(where: {
            $0.recordedAt < startOfToday && $0.recordedAt >= startOfPreviousDay
        }) {
            return TodayUsage(
                status: .exact,
                utilizationDeltaPercent: max(0, weeklyUtilizationPercent - baseline.weeklyUtilizationPercent),
                baselineRecordedAt: baseline.recordedAt
            )
        }

        if let sameDayBaseline = sortedSnapshots.first(where: { snapshot in
            snapshot.recordedAt >= startOfToday && snapshot.recordedAt <= now
        }) {
            return TodayUsage(
                status: .estimatedFromSameDayBaseline,
                utilizationDeltaPercent: max(0, weeklyUtilizationPercent - sameDayBaseline.weeklyUtilizationPercent),
                baselineRecordedAt: sameDayBaseline.recordedAt
            )
        }

        return TodayUsage(status: .unknown)
    }
}
