import Foundation
import PitwallCore
@testable import PitwallShared

actor InMemoryProviderConfigurationStorage: ProviderConfigurationStorage {
    private var snapshot: ProviderConfigurationSnapshot

    init(initial: ProviderConfigurationSnapshot = ProviderConfigurationSnapshot()) {
        self.snapshot = initial
    }

    func load() async -> ProviderConfigurationSnapshot {
        snapshot
    }

    func save(_ snapshot: ProviderConfigurationSnapshot) async throws {
        self.snapshot = snapshot
    }
}

actor InMemoryProviderHistoryStorage: ProviderHistoryStorage {
    private var snapshots: [ProviderHistorySnapshot] = []

    func load() async -> [ProviderHistorySnapshot] {
        snapshots
    }

    func save(_ snapshots: [ProviderHistorySnapshot]) async throws {
        self.snapshots = snapshots
    }

    func append(
        _ snapshot: ProviderHistorySnapshot,
        now: Date,
        maximumRetentionInterval: TimeInterval
    ) async throws {
        snapshots.append(snapshot)
        snapshots = ProviderHistoryRetention(
            now: now,
            maximumRetentionInterval: maximumRetentionInterval
        ).retainedSnapshots(from: snapshots)
    }
}

actor InMemorySettingsStorage: SettingsStorage {
    private var preferences: UserPreferences

    init(initial: UserPreferences = UserPreferences()) {
        self.preferences = initial
    }

    func loadPreferences() async -> UserPreferences {
        preferences
    }

    func savePreferences(_ preferences: UserPreferences) async throws {
        self.preferences = preferences
    }
}
