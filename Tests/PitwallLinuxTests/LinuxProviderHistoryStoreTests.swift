import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallLinux

final class LinuxProviderHistoryStoreTests: XCTestCase {
    private var directory: URL!
    private var root: LinuxStorageRoot!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        root = LinuxStorageRoot(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func snapshot(
        accountId: String = "acct-1",
        recordedAt: Date,
        weekly: Double? = 12.5
    ) -> ProviderHistorySnapshot {
        ProviderHistorySnapshot(
            accountId: accountId,
            recordedAt: recordedAt,
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 10,
            weeklyUtilizationPercent: weekly,
            sessionResetAt: recordedAt.addingTimeInterval(3600),
            weeklyResetAt: recordedAt.addingTimeInterval(7 * 86400),
            headline: "ok"
        )
    }

    func test_load_returnsEmptyWhenMissing() async {
        let store = LinuxProviderHistoryStore(root: root)
        let loaded = await store.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_append_persistsAndRetainsRecentEntriesOnly() async throws {
        let store = LinuxProviderHistoryStore(root: root)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = snapshot(recordedAt: now.addingTimeInterval(-30 * 86400))
        let fresh = snapshot(recordedAt: now.addingTimeInterval(-3600))

        try await store.append(old, now: now, maximumRetentionInterval: 7 * 86400)
        try await store.append(fresh, now: now, maximumRetentionInterval: 7 * 86400)

        let loaded = await store.load()
        XCTAssertEqual(loaded.map(\.recordedAt), [fresh.recordedAt])
    }

    func test_save_thenLoad_roundTripsList() async throws {
        let store = LinuxProviderHistoryStore(root: root)
        let now = Date(timeIntervalSince1970: 1_500_000)
        let items = [
            snapshot(recordedAt: now.addingTimeInterval(-100)),
            snapshot(recordedAt: now.addingTimeInterval(-50))
        ]

        try await store.save(items)
        let loaded = await store.load()

        XCTAssertEqual(loaded.count, items.count)
        XCTAssertEqual(loaded.map(\.recordedAt), items.map(\.recordedAt))
    }
}
