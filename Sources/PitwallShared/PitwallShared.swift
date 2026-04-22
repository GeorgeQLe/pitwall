import Foundation
import PitwallCore

public enum PitwallShared {
    public static let moduleName = "PitwallShared"
    public static let implementationScope = "Cross-platform protocol contracts and portable policy for Pitwall"
    public static let supportedProviders: [ProviderID] = [.claude, .codex, .gemini]
}
