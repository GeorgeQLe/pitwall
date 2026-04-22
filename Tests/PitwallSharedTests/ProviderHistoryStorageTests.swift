import XCTest
import PitwallCore
@testable import PitwallShared

final class ProviderHistoryStorageTests: XCTestCase {
    func testRoundTripSavesAndLoadsHistorySnapshots() async throws {
        let storage = InMemoryProviderHistoryStorage()
        let snapshot = makeSnapshot(accountId: "acct_1", offset: 0)

        try await storage.save([snapshot])
        let reloaded = await storage.load()

        XCTAssertEqual(reloaded, [snapshot])
    }

    func testAppendHonorsMaximumRetentionInterval() async throws {
        let storage = InMemoryProviderHistoryStorage()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let week: TimeInterval = 7 * 24 * 60 * 60

        let ancient = makeSnapshot(
            accountId: "acct_1",
            recordedAt: now.addingTimeInterval(-week - 3600)
        )
        let fresh = makeSnapshot(
            accountId: "acct_1",
            recordedAt: now.addingTimeInterval(-3600)
        )

        try await storage.save([ancient])
        try await storage.append(fresh, now: now, maximumRetentionInterval: week)

        let reloaded = await storage.load()
        XCTAssertEqual(reloaded, [fresh])
    }

    private func makeSnapshot(
        accountId: String,
        recordedAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        offset: TimeInterval = 0
    ) -> ProviderHistorySnapshot {
        ProviderHistorySnapshot(
            accountId: accountId,
            recordedAt: recordedAt.addingTimeInterval(offset),
            providerId: .claude,
            confidence: .exact,
            sessionUtilizationPercent: 42,
            weeklyUtilizationPercent: 37,
            headline: "fixture"
        )
    }
}
