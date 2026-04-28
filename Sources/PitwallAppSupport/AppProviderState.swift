import Foundation
import PitwallCore

public struct AppProviderState: Equatable, Sendable {
    public var providers: [ProviderState]
    public var selectedProviderId: ProviderID?
    public var manualOverrideProviderId: ProviderID?
    public var rotationPaused: Bool
    public var lastRotationAt: Date?

    public init(
        providers: [ProviderState] = [],
        selectedProviderId: ProviderID? = nil,
        manualOverrideProviderId: ProviderID? = nil,
        rotationPaused: Bool = false,
        lastRotationAt: Date? = nil
    ) {
        self.providers = providers
        self.selectedProviderId = selectedProviderId
        self.manualOverrideProviderId = manualOverrideProviderId
        self.rotationPaused = rotationPaused
        self.lastRotationAt = lastRotationAt
    }

    public var orderedProviders: [ProviderState] {
        let preferredOrder = PitwallAppSupport.supportedProviders
        return providers.sorted { lhs, rhs in
            let lhsIndex = preferredOrder.firstIndex(of: lhs.providerId) ?? preferredOrder.count
            let rhsIndex = preferredOrder.firstIndex(of: rhs.providerId) ?? preferredOrder.count

            if lhsIndex == rhsIndex {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            return lhsIndex < rhsIndex
        }
    }

    public var trackedProviders: [ProviderState] {
        orderedProviders.filter(Self.isTrackableProvider)
    }

    public func provider(for providerId: ProviderID?) -> ProviderState? {
        guard let providerId else {
            return nil
        }

        return providers.first { $0.providerId == providerId }
    }

    public func selectedProvider(fallbackToFirst: Bool = true, trackedOnly: Bool = false) -> ProviderState? {
        let candidates = trackedOnly ? trackedProviders : orderedProviders

        if let selectedProviderId,
           let selected = candidates.first(where: { $0.providerId == selectedProviderId }) {
            return selected
        }

        guard fallbackToFirst else {
            return nil
        }

        return candidates.first
    }

    private static func isTrackableProvider(_ provider: ProviderState) -> Bool {
        guard provider.status == .configured else {
            return false
        }

        if provider.pacingState?.weeklyUtilizationPercent != nil
            || provider.pacingState?.dailyBudget?.dailyBudgetPercent != nil
            || provider.pacingState?.todayUsage?.utilizationDeltaPercent != nil {
            return true
        }

        if provider.resetWindow?.resetsAt != nil {
            return true
        }

        if provider.primaryValue?.isEmpty == false {
            return true
        }

        return provider.payloads.contains { payload in
            payload.source == "usageRows"
                || payload.source == "codex-rate-limits"
                || payload.source == "gemini-quota"
        }
    }
}
