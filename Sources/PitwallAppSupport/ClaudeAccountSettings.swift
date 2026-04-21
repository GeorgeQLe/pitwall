import Foundation
import PitwallCore

public struct ClaudeCredentialInput: Equatable, Sendable {
    public var accountId: String
    public var label: String
    public var organizationId: String
    public var sessionKey: String

    public init(
        accountId: String,
        label: String,
        organizationId: String,
        sessionKey: String
    ) {
        self.accountId = accountId
        self.label = label
        self.organizationId = organizationId
        self.sessionKey = sessionKey
    }
}

public struct ClaudeAccountSetupState: Equatable, CustomStringConvertible, Sendable {
    public var accountId: String
    public var label: String
    public var organizationId: String
    public var secretState: ProviderSecretState
    public var isEnabled: Bool
    public var lastSuccessfulRefreshAt: Date?
    public var lastErrorDescription: String?

    public var renderedSessionKey: String? {
        nil
    }

    public var description: String {
        "ClaudeAccountSetupState(accountId: \(accountId), label: \(label), organizationId: \(organizationId), secretStatus: \(secretState.status.rawValue), isEnabled: \(isEnabled))"
    }
}

public actor ClaudeAccountSettings {
    public static let sessionKeyPurpose = "sessionKey"

    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore

    public init(
        configurationStore: ProviderConfigurationStore,
        secretStore: any ProviderSecretStore
    ) {
        self.configurationStore = configurationStore
        self.secretStore = secretStore
    }

    public func saveCredentials(_ input: ClaudeCredentialInput) async throws -> ClaudeAccountSetupState {
        let account = ClaudeAccountConfiguration(
            id: input.accountId,
            label: input.label,
            organizationId: input.organizationId,
            isEnabled: true,
            isAuthExpired: false,
            lastErrorDescription: nil
        )

        let key = secretKey(accountId: input.accountId)
        try await secretStore.save(input.sessionKey, for: key)
        try await configurationStore.upsertClaudeAccount(account)

        return try await setupState(for: account)
    }

    public func deleteCredentials(accountId: String) async throws {
        try await secretStore.deleteSecret(for: secretKey(accountId: accountId))
        try await configurationStore.deleteClaudeAccount(id: accountId)
    }

    public func markExpired(accountId: String, errorDescription: String? = nil) async throws {
        try await configurationStore.update { snapshot in
            var snapshot = snapshot
            snapshot.claudeAccounts = snapshot.claudeAccounts.map { account in
                guard account.id == accountId else {
                    return account
                }

                var account = account
                account.isAuthExpired = true
                account.lastErrorDescription = errorDescription
                return account
            }
            return snapshot
        }
    }

    public func setupStates() async throws -> [ClaudeAccountSetupState] {
        let snapshot = await configurationStore.load()
        var states: [ClaudeAccountSetupState] = []
        for account in snapshot.claudeAccounts {
            states.append(try await setupState(for: account))
        }
        return states
    }

    public func setupState(accountId: String) async throws -> ClaudeAccountSetupState? {
        let snapshot = await configurationStore.load()
        guard let account = snapshot.claudeAccounts.first(where: { $0.id == accountId }) else {
            return nil
        }
        return try await setupState(for: account)
    }

    private func setupState(for account: ClaudeAccountConfiguration) async throws -> ClaudeAccountSetupState {
        let secretState = try await ProviderSecretState.makePublicState(
            providerId: .claude,
            accountId: account.id,
            purpose: Self.sessionKeyPurpose,
            store: secretStore,
            isExpired: account.isAuthExpired
        )

        return ClaudeAccountSetupState(
            accountId: account.id,
            label: account.label,
            organizationId: account.organizationId,
            secretState: secretState,
            isEnabled: account.isEnabled,
            lastSuccessfulRefreshAt: account.lastSuccessfulRefreshAt,
            lastErrorDescription: account.lastErrorDescription
        )
    }

    private func secretKey(accountId: String) -> ProviderSecretKey {
        ProviderSecretKey(
            providerId: .claude,
            accountId: accountId,
            purpose: Self.sessionKeyPurpose
        )
    }
}
