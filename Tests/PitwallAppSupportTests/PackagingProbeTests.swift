import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class PackagingProbeTests: XCTestCase {
    func testFirstRunWritesTwoEventsAndSetsFirstLaunchKey() async throws {
        let env = try makeEnvironment()
        let defaults = isolatedDefaults()
        let eventStore = DiagnosticEventStore(
            userDefaults: defaults,
            storageKey: "test.events.\(UUID().uuidString)",
            lastSuccessfulWriteKey: "test.events.lastWrite.\(UUID().uuidString)"
        )
        let probe = PackagingProbe(
            appSupportRoot: env.appSupportRoot,
            secretStore: InMemorySecretStore(),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let firstLaunchKey = "test.probe.firstLaunch.\(UUID().uuidString)"

        let result = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: firstLaunchKey
        )

        let events = await eventStore.load()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].summary, PackagingProbe.appSupportProbeSummary)
        XCTAssertEqual(events[1].summary, PackagingProbe.keychainProbeSummary)
        XCTAssertTrue(defaults.bool(forKey: firstLaunchKey))
        XCTAssertEqual(result?.appSupportWritable, true)
        XCTAssertNil(result?.appSupportError)
        XCTAssertEqual(result?.keychainRoundTripSucceeded, true)
        XCTAssertNil(result?.keychainError)
        XCTAssertEqual(events[0].details["writable"], "true")
        XCTAssertEqual(events[0].details["path"], env.appSupportRoot.path)
        XCTAssertEqual(events[1].details["roundTripSucceeded"], "true")
    }

    func testSecondRunIsNoOpWhenFirstLaunchKeyAlreadySet() async throws {
        let env = try makeEnvironment()
        let defaults = isolatedDefaults()
        let eventStore = DiagnosticEventStore(
            userDefaults: defaults,
            storageKey: "test.events.\(UUID().uuidString)",
            lastSuccessfulWriteKey: "test.events.lastWrite.\(UUID().uuidString)"
        )
        let probe = PackagingProbe(
            appSupportRoot: env.appSupportRoot,
            secretStore: InMemorySecretStore()
        )
        let firstLaunchKey = "test.probe.firstLaunch.\(UUID().uuidString)"

        _ = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: firstLaunchKey
        )
        let eventsAfterFirst = await eventStore.load()
        let secondResult = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: firstLaunchKey
        )
        let eventsAfterSecond = await eventStore.load()

        XCTAssertNil(secondResult)
        XCTAssertEqual(eventsAfterFirst.count, 2)
        XCTAssertEqual(eventsAfterSecond.count, 2)
    }

    func testApplicationSupportWriteFailureIsReportedWithErrorString() async throws {
        let env = try makeEnvironment()
        let blocker = env.tmpRoot.appendingPathComponent("blocker")
        try Data("blocker".utf8).write(to: blocker, options: .atomic)

        let defaults = isolatedDefaults()
        let eventStore = DiagnosticEventStore(
            userDefaults: defaults,
            storageKey: "test.events.\(UUID().uuidString)",
            lastSuccessfulWriteKey: "test.events.lastWrite.\(UUID().uuidString)"
        )
        let probe = PackagingProbe(
            appSupportRoot: blocker,
            secretStore: InMemorySecretStore()
        )

        let result = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: "test.probe.firstLaunch.\(UUID().uuidString)"
        )

        XCTAssertEqual(result?.appSupportWritable, false)
        XCTAssertNotNil(result?.appSupportError)

        let events = await eventStore.load()
        let appSupportEvent = events.first { $0.summary == PackagingProbe.appSupportProbeSummary }
        XCTAssertNotNil(appSupportEvent)
        XCTAssertEqual(appSupportEvent?.details["writable"], "false")
        XCTAssertNotNil(appSupportEvent?.details["error"])
        XCTAssertFalse(appSupportEvent?.details["error"]?.isEmpty ?? true)
    }

    func testKeychainRoundTripMismatchIsReported() async throws {
        let env = try makeEnvironment()
        let defaults = isolatedDefaults()
        let eventStore = DiagnosticEventStore(
            userDefaults: defaults,
            storageKey: "test.events.\(UUID().uuidString)",
            lastSuccessfulWriteKey: "test.events.lastWrite.\(UUID().uuidString)"
        )
        let probe = PackagingProbe(
            appSupportRoot: env.appSupportRoot,
            secretStore: MismatchingSecretStore()
        )

        let result = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: "test.probe.firstLaunch.\(UUID().uuidString)"
        )

        XCTAssertEqual(result?.keychainRoundTripSucceeded, false)
        XCTAssertEqual(result?.keychainError, "roundTripMismatch")

        let events = await eventStore.load()
        let keychainEvent = events.first { $0.summary == PackagingProbe.keychainProbeSummary }
        XCTAssertNotNil(keychainEvent)
        XCTAssertEqual(keychainEvent?.details["roundTripSucceeded"], "false")
        XCTAssertEqual(keychainEvent?.details["error"], "roundTripMismatch")
    }

    func testKeychainSaveFailureIsReportedWithErrorString() async throws {
        let env = try makeEnvironment()
        let defaults = isolatedDefaults()
        let eventStore = DiagnosticEventStore(
            userDefaults: defaults,
            storageKey: "test.events.\(UUID().uuidString)",
            lastSuccessfulWriteKey: "test.events.lastWrite.\(UUID().uuidString)"
        )
        let probe = PackagingProbe(
            appSupportRoot: env.appSupportRoot,
            secretStore: ThrowingSecretStore()
        )

        let result = await probe.runOnce(
            eventStore: eventStore,
            defaults: defaults,
            firstLaunchKey: "test.probe.firstLaunch.\(UUID().uuidString)"
        )

        XCTAssertEqual(result?.keychainRoundTripSucceeded, false)
        XCTAssertNotNil(result?.keychainError)

        let events = await eventStore.load()
        let keychainEvent = events.first { $0.summary == PackagingProbe.keychainProbeSummary }
        XCTAssertEqual(keychainEvent?.details["roundTripSucceeded"], "false")
        XCTAssertNotNil(keychainEvent?.details["error"])
    }

    // MARK: - Helpers

    private struct Environment {
        let tmpRoot: URL
        let appSupportRoot: URL
    }

    private func makeEnvironment() throws -> Environment {
        let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PitwallPackagingProbeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tmpRoot)
        }
        return Environment(
            tmpRoot: tmpRoot,
            appSupportRoot: tmpRoot.appendingPathComponent("AppSupport", isDirectory: true)
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "PitwallPackagingProbeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private actor MismatchingSecretStore: ProviderSecretStore {
    func save(_ secret: String, for key: ProviderSecretKey) async throws {}

    func loadSecret(for key: ProviderSecretKey) async throws -> String? {
        "a-different-value-than-what-was-saved"
    }

    func deleteSecret(for key: ProviderSecretKey) async throws {}
}

private struct ProbeTestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private actor ThrowingSecretStore: ProviderSecretStore {
    func save(_ secret: String, for key: ProviderSecretKey) async throws {
        throw ProbeTestError(message: "keychain unavailable")
    }

    func loadSecret(for key: ProviderSecretKey) async throws -> String? { nil }

    func deleteSecret(for key: ProviderSecretKey) async throws {}
}
