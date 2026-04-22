import Foundation
import PitwallCore

public struct PackagingProbeResult: Equatable, Sendable {
    public var appSupportWritable: Bool
    public var appSupportError: String?
    public var keychainRoundTripSucceeded: Bool
    public var keychainError: String?

    public init(
        appSupportWritable: Bool,
        appSupportError: String? = nil,
        keychainRoundTripSucceeded: Bool,
        keychainError: String? = nil
    ) {
        self.appSupportWritable = appSupportWritable
        self.appSupportError = appSupportError
        self.keychainRoundTripSucceeded = keychainRoundTripSucceeded
        self.keychainError = keychainError
    }
}

public final class PackagingProbe: @unchecked Sendable {
    public static let defaultFirstLaunchKey = "pitwall.packaging.probe.firstLaunch.v1"
    public static let appSupportProbeSummary = "appSupportProbe"
    public static let keychainProbeSummary = "keychainProbe"

    private let fileManager: FileManager
    private let appSupportRoot: URL
    private let secretStore: any ProviderSecretStore
    private let probeSecretKey: ProviderSecretKey
    private let now: @Sendable () -> Date

    public init(
        fileManager: FileManager = .default,
        appSupportRoot: URL,
        secretStore: any ProviderSecretStore,
        probeSecretKey: ProviderSecretKey = ProviderSecretKey(
            providerId: ProviderID(rawValue: "packaging-probe"),
            accountId: "probe",
            purpose: "probe"
        ),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.appSupportRoot = appSupportRoot
        self.secretStore = secretStore
        self.probeSecretKey = probeSecretKey
        self.now = now
    }

    @discardableResult
    public func runOnce(
        eventStore: DiagnosticEventStore,
        defaults: UserDefaults,
        firstLaunchKey: String = PackagingProbe.defaultFirstLaunchKey
    ) async -> PackagingProbeResult? {
        guard !defaults.bool(forKey: firstLaunchKey) else {
            return nil
        }

        let appSupport = runAppSupportProbe()
        let keychain = await runKeychainProbe()
        let timestamp = now()

        let result = PackagingProbeResult(
            appSupportWritable: appSupport.success,
            appSupportError: appSupport.error,
            keychainRoundTripSucceeded: keychain.success,
            keychainError: keychain.error
        )

        var appSupportDetails: [String: String] = [
            "writable": String(appSupport.success),
            "path": appSupportRoot.path
        ]
        if let error = appSupport.error {
            appSupportDetails["error"] = error
        }

        var keychainDetails: [String: String] = [
            "roundTripSucceeded": String(keychain.success)
        ]
        if let error = keychain.error {
            keychainDetails["error"] = error
        }

        try? await eventStore.append(
            DiagnosticEvent(
                occurredAt: timestamp,
                summary: Self.appSupportProbeSummary,
                details: appSupportDetails
            )
        )
        try? await eventStore.append(
            DiagnosticEvent(
                occurredAt: timestamp,
                summary: Self.keychainProbeSummary,
                details: keychainDetails
            )
        )

        defaults.set(true, forKey: firstLaunchKey)
        return result
    }

    private func runAppSupportProbe() -> (success: Bool, error: String?) {
        do {
            try fileManager.createDirectory(
                at: appSupportRoot,
                withIntermediateDirectories: true
            )
            let probeFile = appSupportRoot.appendingPathComponent(".packaging-probe")
            try Data("ok".utf8).write(to: probeFile, options: .atomic)
            try? fileManager.removeItem(at: probeFile)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func runKeychainProbe() async -> (success: Bool, error: String?) {
        let expected = UUID().uuidString
        do {
            try await secretStore.save(expected, for: probeSecretKey)
            let loaded = try await secretStore.loadSecret(for: probeSecretKey)
            try? await secretStore.deleteSecret(for: probeSecretKey)
            guard loaded == expected else {
                return (false, "roundTripMismatch")
            }
            return (true, nil)
        } catch {
            _ = try? await secretStore.deleteSecret(for: probeSecretKey)
            return (false, error.localizedDescription)
        }
    }
}
