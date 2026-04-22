import Foundation
import PitwallCore

public struct HistoryPreferences: Equatable, Sendable {
    public var isEnabled: Bool
    public var retentionDays: Int

    public init(isEnabled: Bool = true, retentionDays: Int = 7) {
        self.isEnabled = isEnabled
        self.retentionDays = max(1, retentionDays)
    }

    public var maximumRetentionInterval: TimeInterval {
        TimeInterval(retentionDays) * 24 * 60 * 60
    }
}

public struct DiagnosticsPreferences: Equatable, Sendable {
    public var includeRecentEvents: Bool

    public init(includeRecentEvents: Bool = true) {
        self.includeRecentEvents = includeRecentEvents
    }
}

public struct GitHubHeatmapSettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var username: String
    public var lastRefreshAt: Date?
    public var tokenState: GitHubHeatmapTokenStatus

    public init(
        isEnabled: Bool = false,
        username: String = "",
        lastRefreshAt: Date? = nil,
        tokenState: GitHubHeatmapTokenStatus = .missing
    ) {
        self.isEnabled = isEnabled
        self.username = username
        self.lastRefreshAt = lastRefreshAt
        self.tokenState = tokenState
    }
}

public struct Phase4Settings: Equatable, Sendable {
    public var history: HistoryPreferences
    public var diagnostics: DiagnosticsPreferences
    public var notifications: NotificationPreferences
    public var gitHubHeatmap: GitHubHeatmapSettings

    public init(
        history: HistoryPreferences = HistoryPreferences(),
        diagnostics: DiagnosticsPreferences = DiagnosticsPreferences(),
        notifications: NotificationPreferences = NotificationPreferences(),
        gitHubHeatmap: GitHubHeatmapSettings = GitHubHeatmapSettings()
    ) {
        self.history = history
        self.diagnostics = diagnostics
        self.notifications = notifications
        self.gitHubHeatmap = gitHubHeatmap
    }
}

public actor Phase4SettingsStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "pitwall.phase4.settings.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> Phase4Settings {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let stored = try? decoder.decode(StoredPhase4Settings.self, from: data)
        else {
            return Phase4Settings()
        }

        return stored.settings
    }

    public func save(_ settings: Phase4Settings) throws {
        let stored = StoredPhase4Settings(settings)
        let data = try encoder.encode(stored)
        userDefaults.set(data, forKey: storageKey)
    }
}

private struct StoredPhase4Settings: Codable {
    var history: StoredHistoryPreferences
    var diagnostics: StoredDiagnosticsPreferences
    var notifications: StoredPhase4NotificationPreferences
    var gitHubHeatmap: StoredGitHubHeatmapSettings

    init(_ settings: Phase4Settings) {
        history = StoredHistoryPreferences(settings.history)
        diagnostics = StoredDiagnosticsPreferences(settings.diagnostics)
        notifications = StoredPhase4NotificationPreferences(settings.notifications)
        gitHubHeatmap = StoredGitHubHeatmapSettings(settings.gitHubHeatmap)
    }

    var settings: Phase4Settings {
        Phase4Settings(
            history: history.preferences,
            diagnostics: diagnostics.preferences,
            notifications: notifications.preferences,
            gitHubHeatmap: gitHubHeatmap.settings
        )
    }
}

private struct StoredHistoryPreferences: Codable {
    var isEnabled: Bool
    var retentionDays: Int

    init(_ preferences: HistoryPreferences) {
        isEnabled = preferences.isEnabled
        retentionDays = preferences.retentionDays
    }

    var preferences: HistoryPreferences {
        HistoryPreferences(isEnabled: isEnabled, retentionDays: retentionDays)
    }
}

private struct StoredDiagnosticsPreferences: Codable {
    var includeRecentEvents: Bool

    init(_ preferences: DiagnosticsPreferences) {
        includeRecentEvents = preferences.includeRecentEvents
    }

    var preferences: DiagnosticsPreferences {
        DiagnosticsPreferences(includeRecentEvents: includeRecentEvents)
    }
}

private struct StoredPhase4NotificationPreferences: Codable {
    var resetNotificationsEnabled: Bool
    var expiredAuthNotificationsEnabled: Bool
    var telemetryDegradedNotificationsEnabled: Bool
    var pacingThresholdNotificationsEnabled: Bool
    var pacingThreshold: String

    init(_ preferences: NotificationPreferences) {
        resetNotificationsEnabled = preferences.resetNotificationsEnabled
        expiredAuthNotificationsEnabled = preferences.expiredAuthNotificationsEnabled
        telemetryDegradedNotificationsEnabled = preferences.telemetryDegradedNotificationsEnabled
        pacingThresholdNotificationsEnabled = preferences.pacingThresholdNotificationsEnabled
        pacingThreshold = preferences.pacingThreshold.rawValue
    }

    var preferences: NotificationPreferences {
        NotificationPreferences(
            resetNotificationsEnabled: resetNotificationsEnabled,
            expiredAuthNotificationsEnabled: expiredAuthNotificationsEnabled,
            telemetryDegradedNotificationsEnabled: telemetryDegradedNotificationsEnabled,
            pacingThresholdNotificationsEnabled: pacingThresholdNotificationsEnabled,
            pacingThreshold: PacingLabel(rawValue: pacingThreshold) ?? .warning
        )
    }
}

private struct StoredGitHubHeatmapSettings: Codable {
    var isEnabled: Bool
    var username: String
    var lastRefreshAt: Date?
    var tokenState: GitHubHeatmapTokenStatus

    init(_ settings: GitHubHeatmapSettings) {
        isEnabled = settings.isEnabled
        username = settings.username
        lastRefreshAt = settings.lastRefreshAt
        tokenState = settings.tokenState
    }

    var settings: GitHubHeatmapSettings {
        GitHubHeatmapSettings(
            isEnabled: isEnabled,
            username: username,
            lastRefreshAt: lastRefreshAt,
            tokenState: tokenState
        )
    }
}
