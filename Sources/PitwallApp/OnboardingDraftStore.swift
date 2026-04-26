import Foundation
import PitwallAppSupport
import PitwallCore

struct OnboardingDraft {
    var profiles: [ProviderProfileConfiguration]
    var preferences: UserPreferences
    var selectedProviders: Set<ProviderID>
    var currentIndex: Int
}

struct OnboardingDraftStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "pitwall.onboarding.draft.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func load() -> OnboardingDraft? {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let stored = try? decoder.decode(StoredOnboardingDraft.self, from: data)
        else {
            return nil
        }
        return stored.draft
    }

    func save(_ draft: OnboardingDraft) {
        guard let data = try? encoder.encode(StoredOnboardingDraft(draft: draft)) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }
}

private struct StoredOnboardingDraft: Codable {
    var profiles: [StoredProviderProfile]
    var preferences: StoredPreferences
    var selectedProviderIds: [String]
    var currentIndex: Int

    init(draft: OnboardingDraft) {
        profiles = draft.profiles.map(StoredProviderProfile.init)
        preferences = StoredPreferences(draft.preferences)
        selectedProviderIds = draft.selectedProviders.map(\.rawValue).sorted()
        currentIndex = draft.currentIndex
    }

    var draft: OnboardingDraft {
        OnboardingDraft(
            profiles: profiles.map(\.profile),
            preferences: preferences.preferences,
            selectedProviders: Set(selectedProviderIds.map(ProviderID.init(rawValue:))),
            currentIndex: currentIndex
        )
    }
}

private struct StoredProviderProfile: Codable {
    var providerId: String
    var isEnabled: Bool
    var accountLabel: String?
    var planProfile: String?
    var authMode: String?
    var telemetryEnabled: Bool
    var accuracyModeEnabled: Bool
    var lastConfidenceExplanation: String?

    init(_ profile: ProviderProfileConfiguration) {
        providerId = profile.providerId.rawValue
        isEnabled = profile.isEnabled
        accountLabel = profile.accountLabel
        planProfile = profile.planProfile
        authMode = profile.authMode
        telemetryEnabled = profile.telemetryEnabled
        accuracyModeEnabled = profile.accuracyModeEnabled
        lastConfidenceExplanation = profile.lastConfidenceExplanation
    }

    var profile: ProviderProfileConfiguration {
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

private struct StoredPreferences: Codable {
    var resetDisplayPreference: String
    var providerRotationMode: String
    var pinnedProviderId: String?
    var rotationInterval: TimeInterval
    var notificationPreferences: StoredNotificationPreferences

    init(_ preferences: UserPreferences) {
        resetDisplayPreference = preferences.resetDisplayPreference.rawValue
        providerRotationMode = preferences.providerRotationMode.rawValue
        pinnedProviderId = preferences.pinnedProviderId?.rawValue
        rotationInterval = preferences.rotationInterval
        notificationPreferences = StoredNotificationPreferences(preferences.notificationPreferences)
    }

    var preferences: UserPreferences {
        UserPreferences(
            resetDisplayPreference: ResetDisplayPreference(rawValue: resetDisplayPreference) ?? .countdown,
            providerRotationMode: ProviderRotationMode(rawValue: providerRotationMode) ?? .automatic,
            pinnedProviderId: pinnedProviderId.map(ProviderID.init(rawValue:)),
            rotationInterval: rotationInterval,
            notificationPreferences: notificationPreferences.preferences
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
            pacingThreshold: PacingLabel(rawValue: pacingThreshold) ?? .warning
        )
    }
}
