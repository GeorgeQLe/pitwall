import Foundation
import PitwallCore

public struct NotificationPreferences: Equatable, Sendable {
    public var resetNotificationsEnabled: Bool
    public var expiredAuthNotificationsEnabled: Bool
    public var telemetryDegradedNotificationsEnabled: Bool
    public var pacingThresholdNotificationsEnabled: Bool
    public var pacingThreshold: PacingLabel

    public init(
        resetNotificationsEnabled: Bool = true,
        expiredAuthNotificationsEnabled: Bool = true,
        telemetryDegradedNotificationsEnabled: Bool = true,
        pacingThresholdNotificationsEnabled: Bool = false,
        pacingThreshold: PacingLabel = .warning
    ) {
        self.resetNotificationsEnabled = resetNotificationsEnabled
        self.expiredAuthNotificationsEnabled = expiredAuthNotificationsEnabled
        self.telemetryDegradedNotificationsEnabled = telemetryDegradedNotificationsEnabled
        self.pacingThresholdNotificationsEnabled = pacingThresholdNotificationsEnabled
        self.pacingThreshold = pacingThreshold
    }
}
