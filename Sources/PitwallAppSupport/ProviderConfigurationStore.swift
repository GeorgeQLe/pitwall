import Foundation
import PitwallCore
import PitwallShared

public actor ProviderConfigurationStore: ProviderConfigurationStorage {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "pitwall.provider.configuration.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> ProviderConfigurationSnapshot {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let stored = try? decoder.decode(StoredProviderConfiguration.self, from: data)
        else {
            return ProviderConfigurationSnapshot()
        }

        return stored.snapshot
    }

    public func save(_ snapshot: ProviderConfigurationSnapshot) throws {
        let stored = StoredProviderConfiguration(snapshot: snapshot)
        let data = try encoder.encode(stored)
        userDefaults.set(data, forKey: storageKey)
    }

    public func update(
        _ transform: (ProviderConfigurationSnapshot) throws -> ProviderConfigurationSnapshot
    ) throws {
        let updated = try transform(load())
        try save(updated)
    }

    public func upsertClaudeAccount(_ account: ClaudeAccountConfiguration) throws {
        try update { snapshot in
            var snapshot = snapshot
            snapshot.claudeAccounts.removeAll { $0.id == account.id }
            snapshot.claudeAccounts.append(account)
            snapshot.claudeAccounts.sort {
                $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }

            if snapshot.selectedClaudeAccountId == nil {
                snapshot.selectedClaudeAccountId = account.id
            }

            return snapshot
        }
    }

    public func deleteClaudeAccount(id: String) throws {
        try update { snapshot in
            var snapshot = snapshot
            snapshot.claudeAccounts.removeAll { $0.id == id }
            if snapshot.selectedClaudeAccountId == id {
                snapshot.selectedClaudeAccountId = snapshot.claudeAccounts.first?.id
            }
            return snapshot
        }
    }
}

private struct StoredProviderConfiguration: Codable {
    var providerProfiles: [StoredProviderProfileConfiguration]
    var claudeAccounts: [StoredClaudeAccountConfiguration]
    var selectedClaudeAccountId: String?
    var userPreferences: StoredUserPreferences

    init(snapshot: ProviderConfigurationSnapshot) {
        providerProfiles = snapshot.providerProfiles.map(StoredProviderProfileConfiguration.init)
        claudeAccounts = snapshot.claudeAccounts.map(StoredClaudeAccountConfiguration.init)
        selectedClaudeAccountId = snapshot.selectedClaudeAccountId
        userPreferences = StoredUserPreferences(snapshot.userPreferences)
    }

    var snapshot: ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            providerProfiles: providerProfiles.map(\.configuration),
            claudeAccounts: claudeAccounts.map(\.configuration),
            selectedClaudeAccountId: selectedClaudeAccountId,
            userPreferences: userPreferences.preferences
        )
    }
}

private struct StoredProviderProfileConfiguration: Codable {
    var providerId: String
    var isEnabled: Bool
    var accountLabel: String?
    var planProfile: String?
    var authMode: String?
    var telemetryEnabled: Bool
    var accuracyModeEnabled: Bool
    var lastConfidenceExplanation: String?

    init(_ configuration: ProviderProfileConfiguration) {
        providerId = configuration.providerId.rawValue
        isEnabled = configuration.isEnabled
        accountLabel = configuration.accountLabel
        planProfile = configuration.planProfile
        authMode = configuration.authMode
        telemetryEnabled = configuration.telemetryEnabled
        accuracyModeEnabled = configuration.accuracyModeEnabled
        lastConfidenceExplanation = configuration.lastConfidenceExplanation
    }

    var configuration: ProviderProfileConfiguration {
        ProviderProfileConfiguration(
            providerId: ProviderID(rawValue: providerId),
            isEnabled: isEnabled,
            accountLabel: accountLabel,
            planProfile: planProfile,
            authMode: authMode,
            telemetryEnabled: telemetryEnabled,
            accuracyModeEnabled: accuracyModeEnabled,
            lastConfidenceExplanation: lastConfidenceExplanation
        )
    }
}

private struct StoredClaudeAccountConfiguration: Codable {
    var id: String
    var label: String
    var organizationId: String
    var isEnabled: Bool
    var isAuthExpired: Bool
    var lastSuccessfulRefreshAt: Date?
    var lastErrorDescription: String?

    init(_ configuration: ClaudeAccountConfiguration) {
        id = configuration.id
        label = configuration.label
        organizationId = configuration.organizationId
        isEnabled = configuration.isEnabled
        isAuthExpired = configuration.isAuthExpired
        lastSuccessfulRefreshAt = configuration.lastSuccessfulRefreshAt
        lastErrorDescription = configuration.lastErrorDescription
    }

    var configuration: ClaudeAccountConfiguration {
        ClaudeAccountConfiguration(
            id: id,
            label: label,
            organizationId: organizationId,
            isEnabled: isEnabled,
            isAuthExpired: isAuthExpired,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            lastErrorDescription: lastErrorDescription
        )
    }
}

private struct StoredUserPreferences: Codable {
    var resetDisplayPreference: String
    var providerRotationMode: String
    var pinnedProviderId: String?
    var rotationInterval: TimeInterval
    var menuBarTheme: String?
    var menuBarTitleMode: String?
    var notificationPreferences: StoredNotificationPreferences?

    init(_ preferences: UserPreferences) {
        resetDisplayPreference = preferences.resetDisplayPreference.rawValue
        providerRotationMode = preferences.providerRotationMode.rawValue
        pinnedProviderId = preferences.pinnedProviderId?.rawValue
        rotationInterval = preferences.rotationInterval
        menuBarTheme = preferences.menuBarTheme.rawValue
        menuBarTitleMode = preferences.menuBarTitleMode.rawValue
        notificationPreferences = StoredNotificationPreferences(preferences.notificationPreferences)
    }

    var preferences: UserPreferences {
        UserPreferences(
            resetDisplayPreference: ResetDisplayPreference(rawValue: resetDisplayPreference) ?? .countdown,
            providerRotationMode: ProviderRotationMode(rawValue: providerRotationMode) ?? .automatic,
            pinnedProviderId: pinnedProviderId.map(ProviderID.init(rawValue:)),
            rotationInterval: rotationInterval,
            menuBarTheme: MenuBarTheme(rawValue: menuBarTheme ?? "") ?? .running,
            menuBarTitleMode: MenuBarTitleMode(rawValue: menuBarTitleMode ?? "") ?? .compact,
            notificationPreferences: notificationPreferences?.preferences ?? NotificationPreferences()
        )
    }
}

private struct StoredNotificationPreferences: Codable {
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
