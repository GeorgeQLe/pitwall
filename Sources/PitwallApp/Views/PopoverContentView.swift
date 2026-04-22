import PitwallAppSupport
import PitwallCore
import SwiftUI

struct PopoverContentView: View {
    let appState: AppProviderState
    let preferences: UserPreferences
    let historySnapshots: [ProviderHistorySnapshot]
    let gitHubHeatmap: GitHubHeatmap?
    let gitHubHeatmapSettings: GitHubHeatmapSettings
    let onRefresh: () -> Void
    let onRefreshGitHubHeatmap: () -> Void
    let onOpenSettings: () -> Void
    let onAddAccount: () -> Void
    let onSelectProvider: (ProviderID) -> Void

    @AppStorage("pitwall.welcome.v1.dismissed") private var welcomeDismissed: Bool = false

    private var selectedProvider: ProviderState? {
        appState.selectedProvider()
    }

    private var selectedCard: ProviderCardViewModel? {
        selectedProvider.map {
            ProviderCardViewModel(provider: $0, preferences: preferences)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !welcomeDismissed {
                WelcomeBannerView(onDismiss: { welcomeDismissed = true })
            }

            if let selectedCard {
                actionSummary(selectedCard)
            }

            if gitHubHeatmapSettings.isEnabled {
                GitHubHeatmapView(
                    heatmap: gitHubHeatmap,
                    settings: gitHubHeatmapSettings,
                    onRefresh: onRefreshGitHubHeatmap
                )
            }

            providerList
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 430, alignment: .topLeading)
        .frame(minHeight: 560, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pitwall")
                    .font(.system(size: 18, weight: .semibold))
                Text(rotationText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh provider status")

            Button(action: onAddAccount) {
                Image(systemName: "plus")
            }
            .help("Add account")

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .help("Open settings")
        }
        .buttonStyle(.borderless)
    }

    private func actionSummary(_ card: ProviderCardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.recommendedActionText.capitalized)
                    .font(.system(size: 22, weight: .semibold))
                StatusBadgeView(text: card.confidenceText, style: .neutral)
                Spacer()
            }

            Text(card.headline)
                .font(.system(size: 13, weight: .medium))

            HStack(spacing: 10) {
                metricTile(title: "Budget", value: card.secondaryMetric ?? "Unavailable")
                metricTile(title: "Reset", value: card.resetText ?? "Unknown")
                trendTile(for: card.providerId)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
    }

    private func trendTile(for providerId: ProviderID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trend")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            let snapshots = history(for: providerId)
            if snapshots.count > 1 {
                HistorySparklineView(snapshots: snapshots)
                    .frame(height: 28)
            } else {
                Text("No history")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
    }

    private var providerList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(appState.orderedProviders, id: \.providerId) { provider in
                    ProviderCardView(
                        viewModel: ProviderCardViewModel(provider: provider, preferences: preferences),
                        isSelected: provider.providerId == appState.selectedProviderId,
                        historySnapshots: history(for: provider.providerId),
                        onSelect: {
                            onSelectProvider(provider.providerId)
                        },
                        actionHandler: { action in
                            handleAction(action)
                        }
                    )

                    if provider.providerId == .claude {
                        ClaudeUsageRowsView(provider: provider, preferences: preferences)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var rotationText: String {
        if appState.rotationPaused || preferences.providerRotationMode == .paused {
            return "Rotation paused"
        }

        if let provider = selectedProvider {
            return "Showing \(provider.displayName)"
        }

        return "Configure providers"
    }

    private func handleAction(_ action: ProviderAction) {
        switch action.kind {
        case .refresh, .testConnection:
            onRefresh()
        case .configure, .openSettings:
            onOpenSettings()
        case .switchProvider:
            if let providerId = appState.orderedProviders.first(where: { $0.providerId != appState.selectedProviderId })?.providerId {
                onSelectProvider(providerId)
            }
        case .wait:
            break
        }
    }

    private func history(for providerId: ProviderID) -> [ProviderHistorySnapshot] {
        historySnapshots
            .filter { $0.providerId == providerId }
            .sorted { $0.recordedAt < $1.recordedAt }
    }
}
