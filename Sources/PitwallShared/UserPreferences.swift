import Foundation
import PitwallCore

public enum ResetDisplayPreference: String, Equatable, Sendable {
    case countdown
    case resetTime
}

public enum ProviderRotationMode: String, Equatable, Sendable {
    case automatic
    case pinned
    case paused
}

public struct UserPreferences: Equatable, Sendable {
    public var resetDisplayPreference: ResetDisplayPreference
    public var providerRotationMode: ProviderRotationMode
    public var pinnedProviderId: ProviderID?
    public var rotationInterval: TimeInterval
    public var notificationPreferences: NotificationPreferences

    public init(
        resetDisplayPreference: ResetDisplayPreference = .countdown,
        providerRotationMode: ProviderRotationMode = .automatic,
        pinnedProviderId: ProviderID? = nil,
        rotationInterval: TimeInterval = 7,
        notificationPreferences: NotificationPreferences = NotificationPreferences()
    ) {
        self.resetDisplayPreference = resetDisplayPreference
        self.providerRotationMode = providerRotationMode
        self.pinnedProviderId = pinnedProviderId
        self.rotationInterval = max(5, min(10, rotationInterval))
        self.notificationPreferences = notificationPreferences
    }
}
