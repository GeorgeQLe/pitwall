import Foundation
import PitwallCore
import PitwallShared

public struct WindowsClaudeCredentialInput: Equatable, Sendable {
    public var accountId: String
    public var accountLabel: String
    public var organizationId: String
    public var sessionKey: String
    public var lastActiveOrg: String?

    public init(
        accountId: String,
        accountLabel: String,
        organizationId: String,
        sessionKey: String,
        lastActiveOrg: String? = nil
    ) {
        self.accountId = accountId
        self.accountLabel = accountLabel
        self.organizationId = organizationId
        self.sessionKey = sessionKey
        self.lastActiveOrg = lastActiveOrg
    }
}

public enum WindowsClaudeCredentialError: Error, Equatable {
    case missingSessionKey
    case missingOrganizationId
}

/// Manual Claude onboarding flow for the Windows shell. Mirrors the macOS
/// write-only contract: once the session key is saved, it is never rendered
/// back to the UI — callers may only inspect the resulting `ProviderSecretState`.
public actor WindowsClaudeCredentialFlow {
    private let secretStore: any ProviderSecretStore

    public init(secretStore: any ProviderSecretStore) {
        self.secretStore = secretStore
    }

    public func save(_ input: WindowsClaudeCredentialInput) async throws -> ProviderSecretState {
        guard !input.sessionKey.isEmpty else {
            throw WindowsClaudeCredentialError.missingSessionKey
        }
        guard !input.organizationId.isEmpty else {
            throw WindowsClaudeCredentialError.missingOrganizationId
        }

        let sessionKey = ProviderSecretKey(
            providerId: .claude,
            accountId: input.accountId,
            purpose: "sessionKey"
        )
        try await secretStore.save(input.sessionKey, for: sessionKey)

        if let lastActiveOrg = input.lastActiveOrg, !lastActiveOrg.isEmpty {
            let lastActiveOrgKey = ProviderSecretKey(
                providerId: .claude,
                accountId: input.accountId,
                purpose: "lastActiveOrg"
            )
            try await secretStore.save(lastActiveOrg, for: lastActiveOrgKey)
        }

        return try await ProviderSecretState.makePublicState(
            providerId: .claude,
            accountId: input.accountId,
            purpose: "sessionKey",
            store: secretStore
        )
    }
}
