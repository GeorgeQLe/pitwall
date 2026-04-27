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

public enum MenuBarTheme: String, Equatable, Sendable, CaseIterable {
    case running
    case racecar
    case f1Quali

    public var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .racecar:
            return "Racecar"
        case .f1Quali:
            return "F1 Quali"
        }
    }
}

public struct UserPreferences: Equatable, Sendable {
    public var resetDisplayPreference: ResetDisplayPreference
    public var providerRotationMode: ProviderRotationMode
    public var pinnedProviderId: ProviderID?
    public var rotationInterval: TimeInterval
    public var menuBarTheme: MenuBarTheme
    public var notificationPreferences: NotificationPreferences

    public init(
        resetDisplayPreference: ResetDisplayPreference = .countdown,
        providerRotationMode: ProviderRotationMode = .automatic,
        pinnedProviderId: ProviderID? = nil,
        rotationInterval: TimeInterval = 7,
        menuBarTheme: MenuBarTheme = .running,
        notificationPreferences: NotificationPreferences = NotificationPreferences()
    ) {
        self.resetDisplayPreference = resetDisplayPreference
        self.providerRotationMode = providerRotationMode
        self.pinnedProviderId = pinnedProviderId
        self.rotationInterval = max(5, min(10, rotationInterval))
        self.menuBarTheme = menuBarTheme
        self.notificationPreferences = notificationPreferences
    }
}
