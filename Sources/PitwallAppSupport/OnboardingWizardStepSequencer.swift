import Foundation
import PitwallCore

public enum OnboardingWizardStep: Hashable, Sendable {
    case welcome
    case toolSelection
    case credentials(ProviderID)
    case preferences
    case summary
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
}
