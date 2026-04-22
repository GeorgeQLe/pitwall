import Foundation
import PitwallCore

public enum LinuxSecretServiceError: Error, Equatable {
    case backendUnavailable
    case saveFailed(code: Int32)
    case loadFailed(code: Int32)
    case deleteFailed(code: Int32)
}

/// Thin backend the secret store delegates to. Production wires this to
/// `libsecret` / the `org.freedesktop.Secret.Service` D-Bus API; tests inject
/// an in-memory stub. The protocol stays narrow so no Secret Service / D-Bus
/// types leak into callers on other platforms.
public protocol LinuxSecretServiceBackend: Sendable {
    func write(label: String, attributes: [String: String], secret: String) throws
    func read(attributes: [String: String]) throws -> String?
    func delete(attributes: [String: String]) throws
}

/// In-memory backend for tests and the documented "no Secret Service" fallback.
/// Fails closed when told to: writes raise `backendUnavailable`; reads surface
/// `nil` (never a degraded plaintext default).
public final class InMemoryLinuxSecretBackend: LinuxSecretServiceBackend, @unchecked Sendable {
    private let queue = DispatchQueue(label: "pitwall.linux.secrets.inmemory")
    private var entries: [String: String] = [:]
    private let writesEnabled: Bool

    public init(writesEnabled: Bool = true) {
        self.writesEnabled = writesEnabled
    }

    public func write(label: String, attributes: [String: String], secret: String) throws {
        guard writesEnabled else {
            throw LinuxSecretServiceError.backendUnavailable
        }
        queue.sync { entries[Self.key(for: attributes)] = secret }
    }

    public func read(attributes: [String: String]) throws -> String? {
        guard writesEnabled else {
            // Fail closed: missing backend must surface as "not configured",
            // never a degraded default that leaks state.
            return nil
        }
        return queue.sync { entries[Self.key(for: attributes)] }
    }

    public func delete(attributes: [String: String]) throws {
        guard writesEnabled else { return }
        queue.sync { _ = entries.removeValue(forKey: Self.key(for: attributes)) }
    }

    private static func key(for attributes: [String: String]) -> String {
        attributes
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }
}

public final class LinuxSecretServiceStore: ProviderSecretStore, @unchecked Sendable {
    public static let defaultSchema = "com.pitwall.Credential"
    public static let defaultLabelPrefix = "Pitwall"

    private let backend: LinuxSecretServiceBackend
    private let schema: String
    private let labelPrefix: String

    public init(
        backend: LinuxSecretServiceBackend,
        schema: String = defaultSchema,
        labelPrefix: String = defaultLabelPrefix
    ) {
        self.backend = backend
        self.schema = schema
        self.labelPrefix = labelPrefix
    }

    public func save(_ secret: String, for key: ProviderSecretKey) async throws {
        try backend.write(
            label: label(for: key),
            attributes: attributes(for: key),
            secret: secret
        )
    }

    public func loadSecret(for key: ProviderSecretKey) async throws -> String? {
        try backend.read(attributes: attributes(for: key))
    }

    public func deleteSecret(for key: ProviderSecretKey) async throws {
        try backend.delete(attributes: attributes(for: key))
    }

    public func attributes(for key: ProviderSecretKey) -> [String: String] {
        [
            "schema": schema,
            "provider": key.providerId.rawValue,
            "account": key.accountId,
            "purpose": key.purpose
        ]
    }

    public func label(for key: ProviderSecretKey) -> String {
        "\(labelPrefix): \(key.providerId.rawValue) / \(key.accountId) / \(key.purpose)"
    }
}
