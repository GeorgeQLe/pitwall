import Foundation
import PitwallCore
import PitwallShared

public struct ProviderStateFactory: Sendable {
    public init() {}

    public func normalizedProfiles(
        _ profiles: [ProviderProfileConfiguration]
    ) -> [ProviderProfileConfiguration] {
        PitwallAppSupport.supportedProviders.map { providerId in
            profiles.first(where: { $0.providerId == providerId })
                ?? ProviderProfileConfiguration(providerId: providerId)
        }
    }

    public func providers(
        from snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        existingProviders: [ProviderState]
    ) -> [ProviderState] {
        let profiles = normalizedProfiles(snapshot.providerProfiles)
        return PitwallAppSupport.supportedProviders.map { providerId in
            let profile = profiles.first(where: { $0.providerId == providerId })
                ?? ProviderProfileConfiguration(providerId: providerId)

            guard profile.isEnabled else {
                return disabledProviderState(providerId: providerId, profile: profile)
            }

            if providerId == .claude {
                return claudeProviderState(accounts: claudeAccounts, profile: profile)
            }

            if let existing = existingProviders.first(where: { $0.providerId == providerId }) {
                return existing
            }

            return configurableProviderState(providerId: providerId, profile: profile)
        }
    }

    public func initialAppState(now _: Date) -> AppProviderState {
        return AppProviderState(
            providers: providers(
                from: ProviderConfigurationSnapshot(),
                claudeAccounts: [],
                existingProviders: []
            ),
            selectedProviderId: .claude
        )
    }

    private func claudeProviderState(
        accounts: [ClaudeAccountSetupState],
        profile: ProviderProfileConfiguration
    ) -> ProviderState {
        guard let account = accounts.first else {
            return ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .missingConfiguration,
                confidence: .observedOnly,
                headline: "Claude credentials missing",
                primaryValue: "No account saved",
                secondaryValue: profile.planProfile,
                confidenceExplanation: "Add Claude credentials manually to enable exact provider-supplied usage. No browser cookies are read automatically.",
                actions: [
                    ProviderAction(kind: .configure, title: "Configure"),
                    ProviderAction(kind: .openSettings, title: "Settings")
                ]
            )
        }

        let status: ProviderStatus
        let headline: String
        switch account.secretState.status {
        case .configured:
            status = .configured
            headline = "Ready to refresh"
        case .missing:
            status = .missingConfiguration
            headline = "Claude session key missing"
        case .expired:
            status = .expired
            headline = "Claude auth needs replacement"
        }

        return ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: status,
            confidence: status == .configured ? .providerSupplied : .observedOnly,
            headline: account.lastErrorDescription ?? headline,
            primaryValue: account.label,
            secondaryValue: account.organizationId,
            lastUpdatedAt: account.lastSuccessfulRefreshAt,
            confidenceExplanation: "Claude setup uses the saved Keychain credential state only. The saved session key is never rendered back into settings.",
            actions: [
                ProviderAction(kind: .testConnection, title: "Test"),
                ProviderAction(kind: .refresh, title: "Refresh", isEnabled: status == .configured),
                ProviderAction(kind: .openSettings, title: "Settings")
            ]
        )
    }

    private func configurableProviderState(
        providerId: ProviderID,
        profile: ProviderProfileConfiguration
    ) -> ProviderState {
        ProviderState(
            providerId: providerId,
            displayName: displayName(for: providerId),
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: "\(displayName(for: providerId)) setup pending",
            primaryValue: profile.planProfile ?? "No profile selected",
            secondaryValue: secondaryValue(for: providerId, authMode: profile.authMode),
            confidenceExplanation: "\(displayName(for: providerId)) remains visible as a configurable provider until local metadata or telemetry is available.",
            actions: [
                ProviderAction(kind: .configure, title: "Configure"),
                ProviderAction(kind: .openSettings, title: "Settings")
            ]
        )
    }

    private func disabledProviderState(
        providerId: ProviderID,
        profile: ProviderProfileConfiguration
    ) -> ProviderState {
        ProviderState(
            providerId: providerId,
            displayName: displayName(for: providerId),
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: "\(displayName(for: providerId)) skipped",
            primaryValue: profile.planProfile ?? "Disabled",
            secondaryValue: "Configurable in settings",
            confidenceExplanation: "\(displayName(for: providerId)) was skipped or disabled, but it remains visible so it can be configured later.",
            actions: [
                ProviderAction(kind: .configure, title: "Enable"),
                ProviderAction(kind: .openSettings, title: "Settings")
            ]
        )
    }

    private func displayName(for providerId: ProviderID) -> String {
        switch providerId {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .gemini:
            return "Gemini"
        default:
            return providerId.rawValue.capitalized
        }
    }

    private func secondaryValue(for providerId: ProviderID, authMode: String?) -> String {
        guard let authMode, !authMode.isEmpty else {
            return "Passive detection available"
        }

        if providerId == .codex,
           let mode = CodexAuthMode(rawValue: authMode) {
            return mode.displayName
        }

        return authMode
    }
}
