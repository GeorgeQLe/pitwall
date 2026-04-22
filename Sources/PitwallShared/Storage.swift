import Foundation
import PitwallCore

public protocol ProviderConfigurationStorage: Sendable {
    func load() async -> ProviderConfigurationSnapshot
    func save(_ snapshot: ProviderConfigurationSnapshot) async throws
}

public protocol ProviderHistoryStorage: Sendable {
    func load() async -> [ProviderHistorySnapshot]
    func save(_ snapshots: [ProviderHistorySnapshot]) async throws
    func append(
        _ snapshot: ProviderHistorySnapshot,
        now: Date,
        maximumRetentionInterval: TimeInterval
    ) async throws
}

public protocol SettingsStorage: Sendable {
    func loadPreferences() async -> UserPreferences
    func savePreferences(_ preferences: UserPreferences) async throws
}
