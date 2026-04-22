import Foundation
import PitwallCore

public enum WindowsCredentialManagerError: Error, Equatable {
    case backendUnavailable
    case saveFailed(code: Int32)
    case loadFailed(code: Int32)
    case deleteFailed(code: Int32)
}

/// Thin backend the secret store delegates to. Production wires this to
/// `CredWriteW` / `CredReadW` / `CredDeleteW` from `Advapi32`; tests inject
/// an in-memory stub. The protocol stays narrow so no Win32 types leak into
/// callers on other platforms.
public protocol WindowsCredentialManagerBackend: Sendable {
    func write(target: String, secret: String) throws
    func read(target: String) throws -> String?
    func delete(target: String) throws
}

/// In-memory backend for tests and the documented "no Credential Manager"
/// fallback. Fails closed when told to: writes raise, reads surface `nil`.
public final class InMemoryWindowsCredentialBackend: WindowsCredentialManagerBackend, @unchecked Sendable {
    private let queue = DispatchQueue(label: "pitwall.windows.credentials.inmemory")
    private var entries: [String: String] = [:]
    private let writesEnabled: Bool

    public init(writesEnabled: Bool = true) {
        self.writesEnabled = writesEnabled
    }

    public func write(target: String, secret: String) throws {
        guard writesEnabled else {
            throw WindowsCredentialManagerError.backendUnavailable
        }
        queue.sync { entries[target] = secret }
    }

    public func read(target: String) throws -> String? {
        queue.sync { entries[target] }
    }

    public func delete(target: String) throws {
        queue.sync { _ = entries.removeValue(forKey: target) }
    }
}

public final class WindowsCredentialManagerSecretStore: ProviderSecretStore, @unchecked Sendable {
    public static let defaultTargetPrefix = "Pitwall"

    private let backend: WindowsCredentialManagerBackend
    private let targetPrefix: String

    public init(
        backend: WindowsCredentialManagerBackend,
        targetPrefix: String = defaultTargetPrefix
    ) {
        self.backend = backend
        self.targetPrefix = targetPrefix
    }

    public func save(_ secret: String, for key: ProviderSecretKey) async throws {
        try backend.write(target: targetName(for: key), secret: secret)
    }

    public func loadSecret(for key: ProviderSecretKey) async throws -> String? {
        try backend.read(target: targetName(for: key))
    }

    public func deleteSecret(for key: ProviderSecretKey) async throws {
        try backend.delete(target: targetName(for: key))
    }

    public func targetName(for key: ProviderSecretKey) -> String {
        "\(targetPrefix):\(key.providerId.rawValue):\(key.accountId):\(key.purpose)"
    }
}
