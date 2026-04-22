import Foundation
import PitwallCore

public actor ProviderHistoryStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "pitwall.provider.history.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> [ProviderHistorySnapshot] {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let snapshots = try? decoder.decode([ProviderHistorySnapshot].self, from: data)
        else {
            return []
        }

        return snapshots
    }

    public func save(_ snapshots: [ProviderHistorySnapshot]) throws {
        let data = try encoder.encode(snapshots)
        userDefaults.set(data, forKey: storageKey)
    }

    public func append(
        _ snapshot: ProviderHistorySnapshot,
        now: Date,
        maximumRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) throws {
        var snapshots = load()
        snapshots.append(snapshot)
        let retained = ProviderHistoryRetention(
            now: now,
            maximumRetentionInterval: maximumRetentionInterval
        ).retainedSnapshots(from: snapshots)
        try save(retained)
    }

    public func retainedSnapshots(
        providerId: ProviderID,
        accountId: String,
        now: Date,
        maximumRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) -> [ProviderHistorySnapshot] {
        ProviderHistoryRetention(
            now: now,
            maximumRetentionInterval: maximumRetentionInterval
        )
            .retainedSnapshots(from: load())
            .filter {
                $0.providerId == providerId &&
                    $0.accountId == accountId
            }
    }

    public func retainedUsageSnapshots(
        providerId: ProviderID,
        accountId: String,
        now: Date,
        maximumRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) -> [UsageSnapshot] {
        retainedSnapshots(
            providerId: providerId,
            accountId: accountId,
            now: now,
            maximumRetentionInterval: maximumRetentionInterval
        ).compactMap { snapshot in
            guard let weeklyUtilizationPercent = snapshot.weeklyUtilizationPercent else {
                return nil
            }

            return UsageSnapshot(
                recordedAt: snapshot.recordedAt,
                weeklyUtilizationPercent: weeklyUtilizationPercent
            )
        }
    }
}
