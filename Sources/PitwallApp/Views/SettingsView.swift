import PitwallAppSupport
import PitwallCore
import Sparkle
import SwiftUI

struct SettingsView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let initialCodexSetupState: CodexSetupState
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSavePhase4Settings: (Phase4Settings) async -> String?
    let onSaveGitHubToken: (String, String) async -> GitHubHeatmapTokenStatus?
    let onExportDiagnostics: () async -> String
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onDeleteClaudeCredentials: (String) async -> String?
    let onTestClaudeConnection: (String?) async -> ClaudeConnectionTestOutcome
    let onStartCodexChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onCurrentCodexChatGPTLoginState: () async -> CodexDeviceAuthSessionState
    let onRetryCodexChatGPTLoginBrowser: () async -> CodexDeviceAuthSessionState
    let onCancelCodexChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onConnectCodexAPIKey: (String) async -> CodexConnectionOutcome
    let onDisconnectCodex: () async -> CodexConnectionOutcome
    let onRefreshCodexStatus: () async -> CodexSetupState
    let onRefresh: () -> Void
    let loginItemService: LoginItemService?
    let updater: SPUUpdater?

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var phase4Settings: Phase4Settings
    @State private var message: String?
    @State private var isSaving = false
    @State private var launchAtLoginEnabled: Bool
    @State private var launchAtLoginMessage: String?
    @State private var automaticallyChecksForUpdates: Bool
    @State private var updateCheckInterval: TimeInterval
    @State private var claudeCredentialDraft = ClaudeCredentialDraft()
    @State private var codexSetupState: CodexSetupState

    init(
        snapshot: ProviderConfigurationSnapshot,
        phase4Settings: Phase4Settings,
        claudeAccounts: [ClaudeAccountSetupState],
        codexSetupState: CodexSetupState,
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSavePhase4Settings: @escaping (Phase4Settings) async -> String?,
        onSaveGitHubToken: @escaping (String, String) async -> GitHubHeatmapTokenStatus?,
        onExportDiagnostics: @escaping () async -> String,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onDeleteClaudeCredentials: @escaping (String) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> ClaudeConnectionTestOutcome,
        onStartCodexChatGPTLogin: @escaping () async -> CodexDeviceAuthSessionState,
        onCurrentCodexChatGPTLoginState: @escaping () async -> CodexDeviceAuthSessionState,
        onRetryCodexChatGPTLoginBrowser: @escaping () async -> CodexDeviceAuthSessionState,
        onCancelCodexChatGPTLogin: @escaping () async -> CodexDeviceAuthSessionState,
        onConnectCodexAPIKey: @escaping (String) async -> CodexConnectionOutcome,
        onDisconnectCodex: @escaping () async -> CodexConnectionOutcome,
        onRefreshCodexStatus: @escaping () async -> CodexSetupState,
        onRefresh: @escaping () -> Void,
        loginItemService: LoginItemService? = nil,
        updater: SPUUpdater? = nil
    ) {
        self.claudeAccounts = claudeAccounts
        self.initialCodexSetupState = codexSetupState
        self.onSaveConfiguration = onSaveConfiguration
        self.onSavePhase4Settings = onSavePhase4Settings
        self.onSaveGitHubToken = onSaveGitHubToken
        self.onExportDiagnostics = onExportDiagnostics
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onDeleteClaudeCredentials = onDeleteClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onStartCodexChatGPTLogin = onStartCodexChatGPTLogin
        self.onCurrentCodexChatGPTLoginState = onCurrentCodexChatGPTLoginState
        self.onRetryCodexChatGPTLoginBrowser = onRetryCodexChatGPTLoginBrowser
        self.onCancelCodexChatGPTLogin = onCancelCodexChatGPTLogin
        self.onConnectCodexAPIKey = onConnectCodexAPIKey
        self.onDisconnectCodex = onDisconnectCodex
        self.onRefreshCodexStatus = onRefreshCodexStatus
        self.onRefresh = onRefresh
        self.loginItemService = loginItemService
        self.updater = updater
        _profiles = State(initialValue: Self.normalizedProfiles(from: snapshot.providerProfiles))
        _preferences = State(initialValue: snapshot.userPreferences)
        var initialPhase4Settings = phase4Settings
        initialPhase4Settings.notifications = snapshot.userPreferences.notificationPreferences
        _phase4Settings = State(initialValue: initialPhase4Settings)
        _launchAtLoginEnabled = State(initialValue: loginItemService?.isEnabled ?? false)
        _automaticallyChecksForUpdates = State(initialValue: updater?.automaticallyChecksForUpdates ?? false)
        _updateCheckInterval = State(initialValue: updater?.updateCheckInterval ?? UpdateCheckCadence.daily.interval)
        _codexSetupState = State(initialValue: codexSetupState)
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
                        draft: $claudeCredentialDraft,
                        onSave: onSaveClaudeCredentials,
                        onDelete: onDeleteClaudeCredentials,
                        onTest: onTestClaudeConnection
                    )
                    Divider()
                    CodexCredentialSetupView(
                        profile: codexProfileBinding,
                        setupState: $codexSetupState,
                        onStartChatGPTLogin: onStartCodexChatGPTLogin,
                        onCurrentChatGPTLoginState: onCurrentCodexChatGPTLoginState,
                        onRetryChatGPTLoginBrowser: onRetryCodexChatGPTLoginBrowser,
                        onCancelChatGPTLogin: onCancelCodexChatGPTLogin,
                        onConnectAPIKey: onConnectCodexAPIKey,
                        onDisconnect: onDisconnectCodex,
                        onRefreshStatus: onRefreshCodexStatus
                    )
                    Divider()
                    DisplayPreferencesView(preferences: $preferences)
                    Divider()
                    launchAtLoginSection
                    Divider()
                    if updater != nil {
                        updatesSection
                        Divider()
                    }
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

    private var codexProfileBinding: Binding<ProviderProfileConfiguration> {
        binding(for: .codex)
    }

    private func binding(for providerId: ProviderID) -> Binding<ProviderProfileConfiguration> {
        guard let index = profiles.firstIndex(where: { $0.providerId == providerId }) else {
            return .constant(ProviderProfileConfiguration(providerId: providerId))
        }

        return Binding(
            get: { profiles[index] },
            set: { profiles[index] = $0 }
        )
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

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Updates")
                .font(.system(size: 14, weight: .semibold))

            Button("Check for Updates...") {
                updater?.checkForUpdates()
            }

            Toggle("Automatically check for updates", isOn: automaticallyChecksForUpdatesBinding)

            Picker("Check cadence", selection: updateCheckIntervalBinding) {
                ForEach(UpdateCheckCadence.allCases) { cadence in
                    Text(cadence.title).tag(cadence.interval)
                }
            }
            .disabled(!automaticallyChecksForUpdates)
        }
    }

    private var automaticallyChecksForUpdatesBinding: Binding<Bool> {
        Binding(
            get: { automaticallyChecksForUpdates },
            set: { newValue in
                updater?.automaticallyChecksForUpdates = newValue
                automaticallyChecksForUpdates = updater?.automaticallyChecksForUpdates ?? newValue
            }
        )
    }

    private var updateCheckIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { updateCheckInterval },
            set: { newValue in
                updater?.updateCheckInterval = newValue
                updateCheckInterval = updater?.updateCheckInterval ?? newValue
            }
        )
    }
}

private enum UpdateCheckCadence: CaseIterable, Identifiable {
    case hourly
    case everySixHours
    case daily
    case weekly

    var id: TimeInterval { interval }

    var title: String {
        switch self {
        case .hourly:
            return "Hourly"
        case .everySixHours:
            return "Every 6 hours"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .hourly:
            return 60 * 60
        case .everySixHours:
            return 6 * 60 * 60
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        }
    }
}
