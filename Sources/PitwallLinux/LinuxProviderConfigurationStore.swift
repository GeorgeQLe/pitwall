import Foundation
import PitwallCore
import PitwallShared

public actor LinuxProviderConfigurationStore: ProviderConfigurationStorage {
    public static let defaultFileName = "provider-configuration.v1.json"

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        root: LinuxStorageRoot,
        fileName: String = defaultFileName,
        fileManager: FileManager = .default
    ) {
        self.fileURL = root.fileURL(for: fileName)
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() async -> ProviderConfigurationSnapshot {
        guard
            fileManager.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL),
            let stored = try? decoder.decode(StoredLinuxProviderConfiguration.self, from: data)
        else {
            return ProviderConfigurationSnapshot()
        }
        return stored.snapshot
    }

    public func save(_ snapshot: ProviderConfigurationSnapshot) async throws {
        try ensureDirectoryExists()
        let stored = StoredLinuxProviderConfiguration(snapshot: snapshot)
        let data = try encoder.encode(stored)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func ensureDirectoryExists() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}

struct StoredLinuxProviderConfiguration: Codable {
    var providerProfiles: [StoredLinuxProviderProfile]
    var claudeAccounts: [StoredLinuxClaudeAccount]
    var selectedClaudeAccountId: String?
    var userPreferences: StoredLinuxUserPreferences

    init(snapshot: ProviderConfigurationSnapshot) {
        providerProfiles = snapshot.providerProfiles.map(StoredLinuxProviderProfile.init)
        claudeAccounts = snapshot.claudeAccounts.map(StoredLinuxClaudeAccount.init)
        selectedClaudeAccountId = snapshot.selectedClaudeAccountId
        userPreferences = StoredLinuxUserPreferences(snapshot.userPreferences)
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

struct StoredLinuxProviderProfile: Codable {
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

struct StoredLinuxClaudeAccount: Codable {
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

struct StoredLinuxUserPreferences: Codable {
    var resetDisplayPreference: String
    var providerRotationMode: String
    var pinnedProviderId: String?
    var rotationInterval: TimeInterval
    var menuBarTheme: String?
    var notificationPreferences: StoredLinuxNotificationPreferences?

    init(_ preferences: UserPreferences) {
        resetDisplayPreference = preferences.resetDisplayPreference.rawValue
        providerRotationMode = preferences.providerRotationMode.rawValue
        pinnedProviderId = preferences.pinnedProviderId?.rawValue
        rotationInterval = preferences.rotationInterval
        menuBarTheme = preferences.menuBarTheme.rawValue
        notificationPreferences = StoredLinuxNotificationPreferences(preferences.notificationPreferences)
    }

    var preferences: UserPreferences {
        UserPreferences(
            resetDisplayPreference: ResetDisplayPreference(rawValue: resetDisplayPreference) ?? .countdown,
            providerRotationMode: ProviderRotationMode(rawValue: providerRotationMode) ?? .automatic,
            pinnedProviderId: pinnedProviderId.map(ProviderID.init(rawValue:)),
            rotationInterval: rotationInterval,
            menuBarTheme: MenuBarTheme(rawValue: menuBarTheme ?? "") ?? .running,
            notificationPreferences: notificationPreferences?.preferences ?? NotificationPreferences()
        )
    }
}

struct StoredLinuxNotificationPreferences: Codable {
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
