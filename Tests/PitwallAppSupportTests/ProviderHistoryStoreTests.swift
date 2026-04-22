import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderHistoryStoreTests: XCTestCase {
    func testAppendHonorsConfiguredMaximumRetentionInterval() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = ProviderHistoryStore(userDefaults: isolatedDefaults())

        try await store.save([
            snapshot(recordedAt: now.addingTimeInterval(-25 * 60 * 60))
        ])
        try await store.append(
            snapshot(recordedAt: now.addingTimeInterval(-10 * 60)),
            now: now,
            maximumRetentionInterval: 24 * 60 * 60
        )

        let retained = await store.load()

        XCTAssertEqual(retained.map(\.recordedAt), [
            now.addingTimeInterval(-10 * 60)
        ])
    }

    func testRetainedSnapshotsHonorsConfiguredMaximumRetentionInterval() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = ProviderHistoryStore(userDefaults: isolatedDefaults())
        try await store.save([
            snapshot(recordedAt: now.addingTimeInterval(-25 * 60 * 60)),
            snapshot(recordedAt: now.addingTimeInterval(-30 * 60))
        ])

        let retained = await store.retainedSnapshots(
            providerId: .claude,
            accountId: "account",
            now: now,
            maximumRetentionInterval: 24 * 60 * 60
        )

        XCTAssertEqual(retained.map(\.recordedAt), [
            now.addingTimeInterval(-30 * 60)
        ])
    }

    private func snapshot(recordedAt: Date) -> ProviderHistorySnapshot {
        ProviderHistorySnapshot(
            accountId: "account",
            recordedAt: recordedAt,
            providerId: .claude,
            confidence: .exact,
            sessionUtilizationPercent: 40,
            weeklyUtilizationPercent: 50,
            sessionResetAt: recordedAt.addingTimeInterval(60 * 60),
            weeklyResetAt: recordedAt.addingTimeInterval(24 * 60 * 60),
            headline: "Claude usage"
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PitwallProviderHistoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
