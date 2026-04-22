import Foundation

public struct ProviderHistoryRetention: Sendable {
    public var now: Date
    public var fullRetentionInterval: TimeInterval
    public var maximumRetentionInterval: TimeInterval

    public init(
        now: Date,
        fullRetentionInterval: TimeInterval = 24 * 60 * 60,
        maximumRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.now = now
        self.fullRetentionInterval = fullRetentionInterval
        self.maximumRetentionInterval = maximumRetentionInterval
    }

    public func retainedSnapshots(
        from snapshots: [ProviderHistorySnapshot]
    ) -> [ProviderHistorySnapshot] {
        var recent: [ProviderHistorySnapshot] = []
        var downsampleBuckets: [HistoryBucketKey: [ProviderHistorySnapshot]] = [:]

        for snapshot in snapshots {
            let age = now.timeIntervalSince(snapshot.recordedAt)
            guard age >= 0, age <= maximumRetentionInterval else {
                continue
            }

            if age <= fullRetentionInterval {
                recent.append(snapshot)
            } else {
                downsampleBuckets[HistoryBucketKey(snapshot: snapshot), default: []].append(snapshot)
            }
        }

        let downsampled = downsampleBuckets
            .values
            .compactMap(Self.mergeHourlyBucket)

        return (recent + downsampled).sorted { lhs, rhs in
            if lhs.recordedAt == rhs.recordedAt {
                return lhs.providerId.rawValue < rhs.providerId.rawValue
            }
            return lhs.recordedAt < rhs.recordedAt
        }
    }

    private static func mergeHourlyBucket(
        _ snapshots: [ProviderHistorySnapshot]
    ) -> ProviderHistorySnapshot? {
        guard let latest = snapshots.max(by: { $0.recordedAt < $1.recordedAt }) else {
            return nil
        }

        let highestSession = snapshots.max { lhs, rhs in
            utilizationSortValue(lhs.sessionUtilizationPercent) <
                utilizationSortValue(rhs.sessionUtilizationPercent)
        }

        return ProviderHistorySnapshot(
            accountId: latest.accountId,
            recordedAt: latest.recordedAt,
            providerId: latest.providerId,
            confidence: latest.confidence,
            sessionUtilizationPercent: highestSession?.sessionUtilizationPercent,
            weeklyUtilizationPercent: latest.weeklyUtilizationPercent,
            sessionResetAt: highestSession?.sessionResetAt,
            weeklyResetAt: latest.weeklyResetAt,
            headline: latest.headline
        )
    }

    private static func utilizationSortValue(_ value: Double?) -> Double {
        value ?? -.infinity
    }
}

private struct HistoryBucketKey: Hashable {
    var accountId: String
    var providerId: ProviderID
    var hour: Int

    init(snapshot: ProviderHistorySnapshot) {
        accountId = snapshot.accountId
        providerId = snapshot.providerId
        hour = Int(floor(snapshot.recordedAt.timeIntervalSince1970 / 3_600))
    }
}
