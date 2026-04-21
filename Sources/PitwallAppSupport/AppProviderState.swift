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

    public func provider(for providerId: ProviderID?) -> ProviderState? {
        guard let providerId else {
            return nil
        }

        return providers.first { $0.providerId == providerId }
    }

    public func selectedProvider(fallbackToFirst: Bool = true) -> ProviderState? {
        if let selected = provider(for: selectedProviderId) {
            return selected
        }

        guard fallbackToFirst else {
            return nil
        }

        return orderedProviders.first
    }
}
