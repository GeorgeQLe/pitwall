import Foundation
import PitwallCore

public enum PitwallAppSupport {
    public static let moduleName = "PitwallAppSupport"
    public static let implementationScope = "App state, formatters, and service coordination for the macOS app"
    public static let supportedProviders: [ProviderID] = [.claude, .codex, .gemini]
}
