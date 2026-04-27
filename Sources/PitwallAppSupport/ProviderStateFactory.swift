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

    public func initialAppState(now: Date) -> AppProviderState {
        let resetWindow = ResetWindow(
            startsAt: now.addingTimeInterval(-4 * 60 * 60),
            resetsAt: now.addingTimeInterval(41 * 60)
        )

        let claudePacing = PacingState(
            weeklyUtilizationPercent: 82,
            remainingWindowDuration: 41 * 60,
            dailyBudget: DailyBudget(
                remainingUtilizationPercent: 18,
                daysRemaining: 0.7,
                dailyBudgetPercent: 25.7,
                todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12)
            ),
            todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12),
            weeklyPace: PaceEvaluation(
                label: .warning,
                action: .conserve,
                paceRatio: 1.24,
                expectedUtilizationPercent: 66,
                remainingWindowDuration: 41 * 60
            )
        )

        let providers = [
            ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .configured,
                confidence: .exact,
                headline: "Conserve until reset",
                primaryValue: "82% used",
                secondaryValue: "25.7% daily budget",
                resetWindow: resetWindow,
                lastUpdatedAt: now.addingTimeInterval(-4 * 60),
                pacingState: claudePacing,
                confidenceExplanation: "Usage comes from provider-supplied account data. No saved credential value is displayed.",
                actions: [
                    ProviderAction(kind: .refresh, title: "Refresh"),
                    ProviderAction(kind: .openSettings, title: "Settings")
                ],
                payloads: [
                    ProviderSpecificPayload(
                        source: "usageRows",
                        values: [
                            "Weekly": "82|41m|warning",
                            "Today": "12|41m|exact"
                        ]
                    )
                ]
            ),
            ProviderState(
                providerId: .codex,
                displayName: "Codex",
                status: .configured,
                confidence: .highConfidence,
                headline: "Available from local signals",
                primaryValue: "High confidence",
                secondaryValue: "Passive metadata only",
                resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(5 * 60 * 60)),
                lastUpdatedAt: now.addingTimeInterval(-22 * 60),
                confidenceExplanation: "Detected from sanitized local metadata. Prompt text, token values, stdout, and source content are not shown.",
                actions: [
                    ProviderAction(kind: .refresh, title: "Scan"),
                    ProviderAction(kind: .openSettings, title: "Configure")
                ]
            ),
            ProviderState(
                providerId: .gemini,
                displayName: "Gemini",
                status: .missingConfiguration,
                confidence: .observedOnly,
                headline: "Ready to configure",
                primaryValue: "No account selected",
                secondaryValue: "Visible as a configurable provider",
                lastUpdatedAt: nil,
                confidenceExplanation: "Gemini remains visible even before setup so it can be enabled later.",
                actions: [
                    ProviderAction(kind: .configure, title: "Configure"),
                    ProviderAction(kind: .openSettings, title: "Settings")
                ]
            )
        ]

        return AppProviderState(
            providers: providers,
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
