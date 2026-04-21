import Foundation
import Security

public enum KeychainSecretStoreError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)
    case invalidStoredData
}

public final class KeychainSecretStore: ProviderSecretStore, @unchecked Sendable {
    private let service: String
    private let accessGroup: String?

    public init(
        service: String = "com.pitwall.provider-secrets",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func save(_ secret: String, for key: ProviderSecretKey) async throws {
        let data = Data(secret.utf8)
        var query = baseQuery(for: key)

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainSecretStoreError.unhandledStatus(updateStatus)
            }
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainSecretStoreError.unhandledStatus(addStatus)
            }
        default:
            throw KeychainSecretStoreError.unhandledStatus(status)
        }
    }

    public func loadSecret(for key: ProviderSecretKey) async throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let secret = String(data: data, encoding: .utf8)
            else {
                throw KeychainSecretStoreError.invalidStoredData
            }
            return secret
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainSecretStoreError.unhandledStatus(status)
        }
    }

    public func deleteSecret(for key: ProviderSecretKey) async throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery(for key: ProviderSecretKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName(for: key)
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func accountName(for key: ProviderSecretKey) -> String {
        [
            key.providerId.rawValue,
            key.accountId,
            key.purpose
        ].joined(separator: ":")
    }
}
