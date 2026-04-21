import Foundation

public actor InMemorySecretStore: ProviderSecretStore {
    private var secrets: [ProviderSecretKey: String]

    public init(secrets: [ProviderSecretKey: String] = [:]) {
        self.secrets = secrets
    }

    public func save(_ secret: String, for key: ProviderSecretKey) throws {
        secrets[key] = secret
    }

    public func loadSecret(for key: ProviderSecretKey) throws -> String? {
        secrets[key]
    }

    public func deleteSecret(for key: ProviderSecretKey) throws {
        secrets[key] = nil
    }
}
