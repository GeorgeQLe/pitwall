import Foundation
import PitwallCore

public struct ProviderProfileConfiguration: Equatable, Sendable {
    public var providerId: ProviderID
    public var isEnabled: Bool
    public var accountLabel: String?
    public var planProfile: String?
    public var authMode: String?
    public var telemetryEnabled: Bool
    public var accuracyModeEnabled: Bool
    public var lastConfidenceExplanation: String?

    public init(
        providerId: ProviderID,
        isEnabled: Bool = true,
        accountLabel: String? = nil,
        planProfile: String? = nil,
        authMode: String? = nil,
        telemetryEnabled: Bool = false,
        accuracyModeEnabled: Bool = false,
        lastConfidenceExplanation: String? = nil
    ) {
        self.providerId = providerId
        self.isEnabled = isEnabled
        self.accountLabel = accountLabel
        self.planProfile = planProfile
        self.authMode = authMode
        self.telemetryEnabled = telemetryEnabled
        self.accuracyModeEnabled = accuracyModeEnabled
        self.lastConfidenceExplanation = lastConfidenceExplanation
    }
}

public struct ClaudeAccountConfiguration: Equatable, Sendable {
    public var id: String
    public var label: String
    public var organizationId: String
    public var isEnabled: Bool
    public var isAuthExpired: Bool
    public var lastSuccessfulRefreshAt: Date?
    public var lastErrorDescription: String?

    public init(
        id: String,
        label: String,
        organizationId: String,
        isEnabled: Bool = true,
        isAuthExpired: Bool = false,
        lastSuccessfulRefreshAt: Date? = nil,
        lastErrorDescription: String? = nil
    ) {
        self.id = id
        self.label = label
        self.organizationId = organizationId
        self.isEnabled = isEnabled
        self.isAuthExpired = isAuthExpired
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
        self.lastErrorDescription = lastErrorDescription
    }

    public var metadata: ClaudeAccountMetadata {
        ClaudeAccountMetadata(
            id: id,
            label: label,
            organizationId: organizationId,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt
        )
    }
}

public struct ProviderConfigurationSnapshot: Equatable, Sendable {
    public var providerProfiles: [ProviderProfileConfiguration]
    public var claudeAccounts: [ClaudeAccountConfiguration]
    public var selectedClaudeAccountId: String?
    public var userPreferences: UserPreferences

    public init(
        providerProfiles: [ProviderProfileConfiguration] = PitwallShared.supportedProviders.map {
            ProviderProfileConfiguration(providerId: $0)
        },
        claudeAccounts: [ClaudeAccountConfiguration] = [],
        selectedClaudeAccountId: String? = nil,
        userPreferences: UserPreferences = UserPreferences()
    ) {
        self.providerProfiles = providerProfiles
        self.claudeAccounts = claudeAccounts
        self.selectedClaudeAccountId = selectedClaudeAccountId
        self.userPreferences = userPreferences
    }
}
