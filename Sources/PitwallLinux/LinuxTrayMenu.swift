import Foundation
import PitwallCore
import PitwallShared

/// Structured model the Linux tray uses to render a provider card row. The
/// actual `AppIndicator` / `libayatana-appindicator` glue consumes this
/// without having to re-derive any business logic.
public struct LinuxProviderCardViewModel: Equatable, Sendable {
    public var providerId: ProviderID
    public var displayName: String
    public var statusText: String
    public var confidenceText: String
    public var metric: String?
    public var headline: String
    public var resetText: String?
    public var recommendedActionText: String?
    public var isSelected: Bool

    public init(
        providerId: ProviderID,
        displayName: String,
        statusText: String,
        confidenceText: String,
        metric: String?,
        headline: String,
        resetText: String?,
        recommendedActionText: String?,
        isSelected: Bool
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.statusText = statusText
        self.confidenceText = confidenceText
        self.metric = metric
        self.headline = headline
        self.resetText = resetText
        self.recommendedActionText = recommendedActionText
        self.isSelected = isSelected
    }
}

public struct LinuxTrayMenuViewModel: Equatable, Sendable {
    public var tooltip: String
    public var providerCards: [LinuxProviderCardViewModel]
    public var settingsAvailable: Bool
    public var diagnosticsExportAvailable: Bool

    public init(
        tooltip: String,
        providerCards: [LinuxProviderCardViewModel],
        settingsAvailable: Bool = true,
        diagnosticsExportAvailable: Bool = true
    ) {
        self.tooltip = tooltip
        self.providerCards = providerCards
        self.settingsAvailable = settingsAvailable
        self.diagnosticsExportAvailable = diagnosticsExportAvailable
    }
}

public struct LinuxTrayMenuBuilder: Sendable {
    private let formatter: LinuxStatusFormatter

    public init(formatter: LinuxStatusFormatter = LinuxStatusFormatter()) {
        self.formatter = formatter
    }

    public func build(
        providers: [ProviderState],
        selectedProviderId: ProviderID?,
        preferences: UserPreferences,
        now: Date = Date()
    ) -> LinuxTrayMenuViewModel {
        let cards = providers.map { provider in
            card(
                for: provider,
                isSelected: provider.providerId == selectedProviderId,
                preferences: preferences,
                now: now
            )
        }

        let selectedProvider = providers.first { $0.providerId == selectedProviderId }
            ?? providers.first

        let tooltip: String
        if let selectedProvider {
            tooltip = formatter.compactTooltip(
                provider: selectedProvider,
                preferences: preferences,
                now: now
            )
        } else {
            tooltip = "Pitwall — configure"
        }

        return LinuxTrayMenuViewModel(
            tooltip: tooltip,
            providerCards: cards
        )
    }

    private func card(
        for provider: ProviderState,
        isSelected: Bool,
        preferences: UserPreferences,
        now: Date
    ) -> LinuxProviderCardViewModel {
        LinuxProviderCardViewModel(
            providerId: provider.providerId,
            displayName: provider.displayName,
            statusText: formatter.statusText(provider.status),
            confidenceText: formatter.confidenceText(provider.confidence),
            metric: formatter.metric(for: provider),
            headline: provider.headline,
            resetText: formatter.resetText(
                resetWindow: provider.resetWindow,
                preference: preferences.resetDisplayPreference,
                now: now
            ),
            recommendedActionText: formatter.recommendedActionText(for: provider),
            isSelected: isSelected
        )
    }
}
