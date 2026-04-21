import Foundation

public enum RefreshTrigger: Equatable, Sendable {
    case automatic
    case manual
    case testConnection
    case reset(Date)
}

public struct RefreshFailureState: Equatable, Sendable {
    public var consecutiveNetworkFailures: Int
    public var consecutiveTelemetryFailures: Int

    public init(
        consecutiveNetworkFailures: Int = 0,
        consecutiveTelemetryFailures: Int = 0
    ) {
        self.consecutiveNetworkFailures = consecutiveNetworkFailures
        self.consecutiveTelemetryFailures = consecutiveTelemetryFailures
    }
}

public struct PollingPolicy: Equatable, Sendable {
    public static let defaultClaudePollingInterval: TimeInterval = 5 * 60
    public static let defaultTelemetryRefreshInterval: TimeInterval = 5 * 60
    public static let defaultPassiveScanCadence: TimeInterval = 15
    public static let filesystemEventDebounce: TimeInterval = 1

    public var claudePollingInterval: TimeInterval
    public var telemetryRefreshInterval: TimeInterval
    public var passiveScanCadence: TimeInterval
    public var telemetryDegradedFailureThreshold: Int

    public init(
        claudePollingInterval: TimeInterval = Self.defaultClaudePollingInterval,
        telemetryRefreshInterval: TimeInterval = Self.defaultTelemetryRefreshInterval,
        passiveScanCadence: TimeInterval = Self.defaultPassiveScanCadence,
        telemetryDegradedFailureThreshold: Int = 3
    ) {
        self.claudePollingInterval = claudePollingInterval
        self.telemetryRefreshInterval = telemetryRefreshInterval
        self.passiveScanCadence = passiveScanCadence
        self.telemetryDegradedFailureThreshold = telemetryDegradedFailureThreshold
    }

    public func nextClaudeRefreshDate(
        lastRefreshAt: Date?,
        resetAt: Date?,
        failureState: RefreshFailureState,
        trigger: RefreshTrigger,
        now: Date
    ) -> Date {
        switch trigger {
        case .manual, .testConnection:
            return now
        case let .reset(resetDate):
            return maxDate(now, resetDate)
        case .automatic:
            break
        }

        let interval = failureState.consecutiveNetworkFailures > 0
            ? networkBackoffDelay(consecutiveFailures: failureState.consecutiveNetworkFailures)
            : claudePollingInterval
        let pollingDate = (lastRefreshAt ?? now).addingTimeInterval(interval)

        guard let resetAt else {
            return maxDate(now, pollingDate)
        }

        return maxDate(now, min(pollingDate, resetAt))
    }

    public func shouldAttemptRefresh(
        lastRefreshAt: Date?,
        resetAt: Date?,
        failureState: RefreshFailureState,
        trigger: RefreshTrigger,
        now: Date
    ) -> Bool {
        switch trigger {
        case .manual, .testConnection:
            return true
        case .automatic, .reset:
            return nextClaudeRefreshDate(
                lastRefreshAt: lastRefreshAt,
                resetAt: resetAt,
                failureState: failureState,
                trigger: trigger,
                now: now
            ) <= now
        }
    }

    public func networkBackoffDelay(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else {
            return 0
        }

        return min(300 * pow(2, Double(consecutiveFailures)), 3_600)
    }

    public func telemetryBackoffDelay(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else {
            return 0
        }

        return min(telemetryRefreshInterval * pow(2, Double(consecutiveFailures)), 30 * 60)
    }

    public func isTelemetryDegraded(consecutiveFailures: Int) -> Bool {
        consecutiveFailures >= telemetryDegradedFailureThreshold
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}
