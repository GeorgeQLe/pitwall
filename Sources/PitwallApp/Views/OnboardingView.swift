import PitwallAppSupport
import PitwallCore
import SwiftUI

struct OnboardingView: View {
    let snapshot: ProviderConfigurationSnapshot
    let claudeAccounts: [ClaudeAccountSetupState]
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onFinish: () -> Void

    init(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onFinish: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.claudeAccounts = claudeAccounts
        self.onSaveConfiguration = onSaveConfiguration
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onFinish = onFinish
    }

    var body: some View {
        OnboardingWizardView(
            snapshot: snapshot,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: onSaveConfiguration,
            onSaveClaudeCredentials: onSaveClaudeCredentials,
            onTestClaudeConnection: onTestClaudeConnection,
            onFinish: onFinish
        )
    }
}
