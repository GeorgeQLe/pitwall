import Foundation
import PitwallCore
import PitwallShared

public struct ProviderRotationDecision: Equatable, Sendable {
    public var selectedProviderId: ProviderID?
    public var lastRotationAt: Date?
    public var reason: Reason

    public init(selectedProviderId: ProviderID?, lastRotationAt: Date?, reason: Reason) {
        self.selectedProviderId = selectedProviderId
        self.lastRotationAt = lastRotationAt
        self.reason = reason
    }

    public enum Reason: String, Equatable, Sendable {
        case noProviders
        case pinned
        case manualOverride
        case paused
        case intervalNotElapsed
        case rotated
        case selectedFallback
    }
}

public struct ProviderRotationController: Sendable {
    public init() {}

    public func nextSelection(
        appState: AppProviderState,
        preferences: UserPreferences = UserPreferences(),
        now: Date = Date()
    ) -> ProviderRotationDecision {
        let candidates = appState.trackedProviders
        guard !candidates.isEmpty else {
            return ProviderRotationDecision(selectedProviderId: nil, lastRotationAt: appState.lastRotationAt, reason: .noProviders)
        }

        if preferences.providerRotationMode == .pinned,
           let pinnedProviderId = preferences.pinnedProviderId,
           candidates.contains(where: { $0.providerId == pinnedProviderId }) {
            return ProviderRotationDecision(selectedProviderId: pinnedProviderId, lastRotationAt: appState.lastRotationAt, reason: .pinned)
        }

        if let manualOverrideProviderId = appState.manualOverrideProviderId,
           candidates.contains(where: { $0.providerId == manualOverrideProviderId }) {
            return ProviderRotationDecision(selectedProviderId: manualOverrideProviderId, lastRotationAt: appState.lastRotationAt, reason: .manualOverride)
        }

        if preferences.providerRotationMode == .paused || appState.rotationPaused {
            return pausedDecision(appState: appState, candidates: candidates)
        }

        let currentProviderId = appState.selectedProviderId
        guard let currentProviderId,
              candidates.contains(where: { $0.providerId == currentProviderId }) else {
            return ProviderRotationDecision(
                selectedProviderId: candidates[0].providerId,
                lastRotationAt: now,
                reason: .selectedFallback
            )
        }

        if let lastRotationAt = appState.lastRotationAt,
           now.timeIntervalSince(lastRotationAt) < preferences.rotationInterval {
            return ProviderRotationDecision(
                selectedProviderId: currentProviderId,
                lastRotationAt: lastRotationAt,
                reason: .intervalNotElapsed
            )
        }

        let nextProviderId = providerAfter(currentProviderId, in: candidates)?.providerId ?? candidates[0].providerId
        return ProviderRotationDecision(
            selectedProviderId: nextProviderId,
            lastRotationAt: now,
            reason: .rotated
        )
    }

    private func pausedDecision(appState: AppProviderState, candidates: [ProviderState]) -> ProviderRotationDecision {
        if let selectedProviderId = appState.selectedProviderId,
           candidates.contains(where: { $0.providerId == selectedProviderId }) {
            return ProviderRotationDecision(
                selectedProviderId: selectedProviderId,
                lastRotationAt: appState.lastRotationAt,
                reason: .paused
            )
        }

        return ProviderRotationDecision(
            selectedProviderId: candidates[0].providerId,
            lastRotationAt: appState.lastRotationAt,
            reason: .paused
        )
    }

    private func providerAfter(_ providerId: ProviderID, in candidates: [ProviderState]) -> ProviderState? {
        guard let index = candidates.firstIndex(where: { $0.providerId == providerId }) else {
            return nil
        }

        let nextIndex = candidates.index(after: index)
        if nextIndex < candidates.endIndex {
            return candidates[nextIndex]
        }

        return candidates.first
    }
}
