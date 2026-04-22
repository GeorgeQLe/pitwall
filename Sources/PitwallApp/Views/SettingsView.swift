import PitwallAppSupport
import PitwallCore
import SwiftUI

struct SettingsView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onDeleteClaudeCredentials: (String) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onRefresh: () -> Void

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var message: String?
    @State private var isSaving = false

    init(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onDeleteClaudeCredentials: @escaping (String) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onRefresh: @escaping () -> Void
    ) {
        self.claudeAccounts = claudeAccounts
        self.onSaveConfiguration = onSaveConfiguration
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onDeleteClaudeCredentials = onDeleteClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onRefresh = onRefresh
        _profiles = State(initialValue: Self.normalizedProfiles(from: snapshot.providerProfiles))
        _preferences = State(initialValue: snapshot.userPreferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProviderEnablementView(profiles: $profiles)
                    Divider()
                    ClaudeCredentialSetupView(
                        accounts: claudeAccounts,
                        onSave: onSaveClaudeCredentials,
                        onDelete: onDeleteClaudeCredentials,
                        onTest: onTestClaudeConnection
                    )
                    Divider()
                    DisplayPreferencesView(preferences: $preferences)
                    Divider()
                    NotificationPreferencesView(preferences: notificationPreferences)
                }
                .padding(.trailing, 6)
            }

            footer
        }
        .padding(18)
        .frame(width: 520, height: 640, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pitwall Settings")
                    .font(.system(size: 20, weight: .semibold))
                Text("Provider setup and menu bar preferences")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh provider status")
        }
        .buttonStyle(.borderless)
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

            Button("Save") {
                Task { await save() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
        }
        .buttonStyle(.borderedProminent)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let snapshot = ProviderConfigurationSnapshot(
            providerProfiles: Self.normalizedProfiles(from: profiles),
            claudeAccounts: [],
            selectedClaudeAccountId: nil,
            userPreferences: preferences
        )

        if let error = await onSaveConfiguration(snapshot) {
            message = error
        } else {
            message = "Settings saved."
        }
    }

    private static func normalizedProfiles(
        from profiles: [ProviderProfileConfiguration]
    ) -> [ProviderProfileConfiguration] {
        PitwallAppSupport.supportedProviders.map { providerId in
            profiles.first(where: { $0.providerId == providerId }) ?? ProviderProfileConfiguration(providerId: providerId)
        }
    }

    private var notificationPreferences: Binding<NotificationPreferences> {
        Binding(
            get: { preferences.notificationPreferences },
            set: { preferences.notificationPreferences = $0 }
        )
    }
}
