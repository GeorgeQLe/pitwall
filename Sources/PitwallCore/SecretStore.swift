import Foundation

public struct ProviderSecretKey: Hashable, Sendable {
    public var providerId: ProviderID
    public var accountId: String
    public var purpose: String

    public init(providerId: ProviderID, accountId: String, purpose: String) {
        self.providerId = providerId
        self.accountId = accountId
        self.purpose = purpose
    }
}

public protocol ProviderSecretStore: Sendable {
    func save(_ secret: String, for key: ProviderSecretKey) async throws
    func loadSecret(for key: ProviderSecretKey) async throws -> String?
    func deleteSecret(for key: ProviderSecretKey) async throws
}

public enum ProviderSecretStatus: String, Equatable, Sendable {
    case configured
    case missing
    case expired
}

public struct ProviderSecretState: Equatable, CustomStringConvertible, Sendable {
    public var providerId: ProviderID
    public var accountId: String
    public var purpose: String
    public var status: ProviderSecretStatus

    public var renderedSecretValue: String? {
        nil
    }

    public var description: String {
        "ProviderSecretState(providerId: \(providerId.rawValue), accountId: \(accountId), purpose: \(purpose), status: \(status.rawValue))"
    }

    public init(
        providerId: ProviderID,
        accountId: String,
        purpose: String,
        status: ProviderSecretStatus
    ) {
        self.providerId = providerId
        self.accountId = accountId
        self.purpose = purpose
        self.status = status
    }

    public static func makePublicState(
        providerId: ProviderID,
        accountId: String,
        purpose: String,
        store: some ProviderSecretStore,
        isExpired: Bool = false
    ) async throws -> ProviderSecretState {
        let key = ProviderSecretKey(
            providerId: providerId,
            accountId: accountId,
            purpose: purpose
        )
        let hasSecret = try await store.loadSecret(for: key) != nil
        let status: ProviderSecretStatus
        if hasSecret {
            status = isExpired ? .expired : .configured
        } else {
            status = .missing
        }

        return ProviderSecretState(
            providerId: providerId,
            accountId: accountId,
            purpose: purpose,
            status: status
        )
    }
}
