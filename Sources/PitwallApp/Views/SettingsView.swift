import PitwallAppSupport
import PitwallCore
import SwiftUI

struct SettingsView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSavePhase4Settings: (Phase4Settings) async -> String?
    let onSaveGitHubToken: (String, String) async -> GitHubHeatmapTokenStatus?
    let onExportDiagnostics: () async -> String
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onDeleteClaudeCredentials: (String) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onRefresh: () -> Void
    let loginItemService: LoginItemService?

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var phase4Settings: Phase4Settings
    @State private var message: String?
    @State private var isSaving = false
    @State private var launchAtLoginEnabled: Bool
    @State private var launchAtLoginMessage: String?

    init(
        snapshot: ProviderConfigurationSnapshot,
        phase4Settings: Phase4Settings,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSavePhase4Settings: @escaping (Phase4Settings) async -> String?,
        onSaveGitHubToken: @escaping (String, String) async -> GitHubHeatmapTokenStatus?,
        onExportDiagnostics: @escaping () async -> String,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onDeleteClaudeCredentials: @escaping (String) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onRefresh: @escaping () -> Void,
        loginItemService: LoginItemService? = nil
    ) {
        self.claudeAccounts = claudeAccounts
        self.onSaveConfiguration = onSaveConfiguration
        self.onSavePhase4Settings = onSavePhase4Settings
        self.onSaveGitHubToken = onSaveGitHubToken
        self.onExportDiagnostics = onExportDiagnostics
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onDeleteClaudeCredentials = onDeleteClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onRefresh = onRefresh
        self.loginItemService = loginItemService
        _profiles = State(initialValue: Self.normalizedProfiles(from: snapshot.providerProfiles))
        _preferences = State(initialValue: snapshot.userPreferences)
        var initialPhase4Settings = phase4Settings
        initialPhase4Settings.notifications = snapshot.userPreferences.notificationPreferences
        _phase4Settings = State(initialValue: initialPhase4Settings)
        _launchAtLoginEnabled = State(initialValue: loginItemService?.isEnabled ?? false)
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
                    launchAtLoginSection
                    Divider()
                    NotificationPreferencesView(preferences: notificationPreferences)
                    Divider()
                    historyAndDiagnosticsSettings
                    Divider()
                    DiagnosticsExportView(onExport: onExportDiagnostics)
                    Divider()
                    GitHubHeatmapSettingsView(
                        settings: gitHubHeatmapSettings,
                        onSaveToken: onSaveGitHubToken
                    )
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
            return
        }

        phase4Settings.notifications = preferences.notificationPreferences
        if let error = await onSavePhase4Settings(phase4Settings) {
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
            set: {
                preferences.notificationPreferences = $0
                phase4Settings.notifications = $0
            }
        )
    }

    private var gitHubHeatmapSettings: Binding<GitHubHeatmapSettings> {
        Binding(
            get: { phase4Settings.gitHubHeatmap },
            set: { phase4Settings.gitHubHeatmap = $0 }
        )
    }

    private var historyAndDiagnosticsSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History And Diagnostics")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Retain derived provider history", isOn: historyEnabled)

            Stepper(
                "History retention: \(phase4Settings.history.retentionDays) days",
                value: historyRetentionDays,
                in: 1...7
            )
            .disabled(!phase4Settings.history.isEnabled)

            Toggle("Include recent redacted diagnostic events", isOn: includeDiagnosticEvents)
        }
    }

    private var historyEnabled: Binding<Bool> {
        Binding(
            get: { phase4Settings.history.isEnabled },
            set: { phase4Settings.history.isEnabled = $0 }
        )
    }

    private var historyRetentionDays: Binding<Int> {
        Binding(
            get: { phase4Settings.history.retentionDays },
            set: { phase4Settings.history.retentionDays = $0 }
        )
    }

    @ViewBuilder
    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Startup")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Launch Pitwall at login", isOn: launchAtLoginBinding)
                .disabled(loginItemService == nil)

            if let launchAtLoginMessage {
                Text(launchAtLoginMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { newValue in
                guard let service = loginItemService else {
                    launchAtLoginEnabled = newValue
                    return
                }
                do {
                    try service.setEnabled(newValue)
                    launchAtLoginEnabled = service.isEnabled
                    launchAtLoginMessage = nil
                } catch {
                    launchAtLoginEnabled = service.isEnabled
                    launchAtLoginMessage = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        )
    }

    private var includeDiagnosticEvents: Binding<Bool> {
        Binding(
            get: { phase4Settings.diagnostics.includeRecentEvents },
            set: { phase4Settings.diagnostics.includeRecentEvents = $0 }
        )
    }
}
