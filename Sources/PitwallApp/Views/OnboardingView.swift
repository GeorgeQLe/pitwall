import PitwallAppSupport
import PitwallCore
import SwiftUI

struct OnboardingView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onFinish: () -> Void

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var message: String?
    @State private var isSaving = false

    init(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onFinish: @escaping () -> Void
    ) {
        self.claudeAccounts = claudeAccounts
        self.onSaveConfiguration = onSaveConfiguration
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onFinish = onFinish
        _profiles = State(initialValue: Self.normalizedProfiles(from: snapshot.providerProfiles))
        _preferences = State(initialValue: snapshot.userPreferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProviderEnablementView(profiles: $profiles)
                    Divider()
                    ClaudeCredentialSetupView(
                        accounts: claudeAccounts,
                        onSave: onSaveClaudeCredentials,
                        onDelete: { _ in "Delete saved accounts from Settings." },
                        onTest: onTestClaudeConnection
                    )
                    Divider()
                    DisplayPreferencesView(preferences: $preferences)
                }
                .padding(.trailing, 6)
            }

            footer
        }
        .padding(18)
        .frame(width: 540, height: 660, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set Up Pitwall")
                .font(.system(size: 22, weight: .semibold))
            Text("Choose visible providers, add Claude credentials if desired, and set menu bar rotation.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Button("Skip") {
                Task { await finish(skipped: true) }
            }
            .disabled(isSaving)

            Button("Finish") {
                Task { await finish(skipped: false) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
        }
        .buttonStyle(.bordered)
    }

    private func finish(skipped: Bool) async {
        isSaving = true
        defer { isSaving = false }

        var profiles = Self.normalizedProfiles(from: profiles)
        if skipped {
            profiles = profiles.map { profile in
                var profile = profile
                profile.isEnabled = false
                return profile
            }
        }

        let snapshot = ProviderConfigurationSnapshot(
            providerProfiles: profiles,
            claudeAccounts: [],
            selectedClaudeAccountId: nil,
            userPreferences: preferences
        )

        if let error = await onSaveConfiguration(snapshot) {
            message = error
        } else {
            onFinish()
        }
    }

    private static func normalizedProfiles(
        from profiles: [ProviderProfileConfiguration]
    ) -> [ProviderProfileConfiguration] {
        PitwallAppSupport.supportedProviders.map { providerId in
            profiles.first(where: { $0.providerId == providerId }) ?? ProviderProfileConfiguration(providerId: providerId)
        }
    }
}
