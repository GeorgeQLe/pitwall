import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallWindows

final class WindowsProviderConfigurationStoreTests: XCTestCase {
    private var root: WindowsStorageRoot!
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        root = WindowsStorageRoot(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_load_returnsDefaultSnapshotWhenFileMissing() async {
        let store = WindowsProviderConfigurationStore(root: root)

        let loaded = await store.load()

        XCTAssertEqual(loaded.selectedClaudeAccountId, nil)
        XCTAssertEqual(loaded.providerProfiles.map(\.providerId), PitwallShared.supportedProviders)
    }

    func test_save_thenLoad_roundTripsSnapshot() async throws {
        let store = WindowsProviderConfigurationStore(root: root)
        var snapshot = ProviderConfigurationSnapshot()
        snapshot.claudeAccounts = [
            ClaudeAccountConfiguration(
                id: "acct-1",
                label: "Primary",
                organizationId: "org-1"
            )
        ]
        snapshot.selectedClaudeAccountId = "acct-1"
        var prefs = snapshot.userPreferences
        prefs.resetDisplayPreference = .resetTime
        snapshot.userPreferences = prefs

        try await store.save(snapshot)
        let loaded = await store.load()

        XCTAssertEqual(loaded.claudeAccounts.map(\.id), ["acct-1"])
        XCTAssertEqual(loaded.selectedClaudeAccountId, "acct-1")
        XCTAssertEqual(loaded.userPreferences.resetDisplayPreference, .resetTime)
    }

    func test_save_createsDirectoryWhenMissing() async throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))

        let store = WindowsProviderConfigurationStore(root: root)
        try await store.save(ProviderConfigurationSnapshot())

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }
}
