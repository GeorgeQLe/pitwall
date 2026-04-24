import Foundation
import PitwallCore

public enum OnboardingWizardStep: Hashable, Sendable {
    case welcome
    case toolSelection
    case credentials(ProviderID)
    case preferences
    case summary
}

public struct OnboardingTrackPosition: Equatable, Sendable {
    public enum Lane: Equatable, Sendable {
        case main(index: Int)
        case pit(index: Int)
    }
    public let lane: Lane
    public let step: OnboardingWizardStep
}

public struct OnboardingWizardStepSequencer {
    public static func steps(
        for selectedProviders: Set<ProviderID>,
        order: [ProviderID] = PitwallAppSupport.supportedProviders
    ) -> [OnboardingWizardStep] {
        var result: [OnboardingWizardStep] = [.welcome, .toolSelection]
        for providerId in order where selectedProviders.contains(providerId) {
            result.append(.credentials(providerId))
        }
        result.append(.preferences)
        result.append(.summary)
        return result
    }

    public static func pitProviders(
        for selectedProviders: Set<ProviderID>,
        order: [ProviderID] = PitwallAppSupport.supportedProviders
    ) -> [ProviderID] {
        order.filter { selectedProviders.contains($0) }
    }

    public static func trackPositions(
        for selectedProviders: Set<ProviderID>,
        order: [ProviderID] = PitwallAppSupport.supportedProviders
    ) -> [OnboardingTrackPosition] {
        var positions: [OnboardingTrackPosition] = [
            OnboardingTrackPosition(lane: .main(index: 0), step: .welcome),
            OnboardingTrackPosition(lane: .main(index: 1), step: .toolSelection),
        ]
        let pits = pitProviders(for: selectedProviders, order: order)
        for (i, providerId) in pits.enumerated() {
            positions.append(OnboardingTrackPosition(lane: .pit(index: i), step: .credentials(providerId)))
        }
        positions.append(OnboardingTrackPosition(lane: .main(index: 2), step: .preferences))
        positions.append(OnboardingTrackPosition(lane: .main(index: 3), step: .summary))
        return positions
    }
}
