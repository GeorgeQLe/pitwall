import Foundation
import PitwallCore
@_exported import PitwallShared

public enum PitwallAppSupport {
    public static let moduleName = "PitwallAppSupport"
    public static let implementationScope = "App state, formatters, and service coordination for the macOS app"
    public static let supportedProviders: [ProviderID] = PitwallShared.supportedProviders
}
