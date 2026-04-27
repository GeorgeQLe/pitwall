import PitwallAppSupport
import PitwallCore
import SwiftUI

struct OnboardingWizardView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let initialCodexSetupState: CodexSetupState
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> ClaudeConnectionTestOutcome
    let onStartCodexChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onCurrentCodexChatGPTLoginState: () async -> CodexDeviceAuthSessionState
    let onRetryCodexChatGPTLoginBrowser: () async -> CodexDeviceAuthSessionState
    let onCancelCodexChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onConnectCodexAPIKey: (String) async -> CodexConnectionOutcome
    let onDisconnectCodex: () async -> CodexConnectionOutcome
    let onRefreshCodexStatus: () async -> CodexSetupState
    let onFinish: () -> Void
    let onUnsavedSensitiveInputChanged: (Bool) -> Void

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var selectedProviders: Set<ProviderID>
    @State private var currentIndex: Int
    @State private var message: String?
    @State private var busyMessage: String?
    @State private var isSaving = false
    @State private var completedSteps: Set<OnboardingWizardStep> = []
    @State private var claudeCredentialsSaved: Bool
    @State private var claudeCredentialDraft: ClaudeCredentialDraft
    @State private var savedClaudeAccountIds: Set<String>
    @State private var codexSetupState: CodexSetupState

    init(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        codexSetupState: CodexSetupState,
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> ClaudeConnectionTestOutcome,
        onStartCodexChatGPTLogin: @escaping () async -> CodexDeviceAuthSessionState,
        onCurrentCodexChatGPTLoginState: @escaping () async -> CodexDeviceAuthSessionState,
        onRetryCodexChatGPTLoginBrowser: @escaping () async -> CodexDeviceAuthSessionState,
        onCancelCodexChatGPTLogin: @escaping () async -> CodexDeviceAuthSessionState,
        onConnectCodexAPIKey: @escaping (String) async -> CodexConnectionOutcome,
        onDisconnectCodex: @escaping () async -> CodexConnectionOutcome,
        onRefreshCodexStatus: @escaping () async -> CodexSetupState,
        onFinish: @escaping () -> Void,
        onUnsavedSensitiveInputChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.claudeAccounts = claudeAccounts
        self.initialCodexSetupState = codexSetupState
        self.onSaveConfiguration = onSaveConfiguration
        self.onSaveClaudeCredentials = onSaveClaudeCredentials
        self.onTestClaudeConnection = onTestClaudeConnection
        self.onStartCodexChatGPTLogin = onStartCodexChatGPTLogin
        self.onCurrentCodexChatGPTLoginState = onCurrentCodexChatGPTLoginState
        self.onRetryCodexChatGPTLoginBrowser = onRetryCodexChatGPTLoginBrowser
        self.onCancelCodexChatGPTLogin = onCancelCodexChatGPTLogin
        self.onConnectCodexAPIKey = onConnectCodexAPIKey
        self.onDisconnectCodex = onDisconnectCodex
        self.onRefreshCodexStatus = onRefreshCodexStatus
        self.onFinish = onFinish
        self.onUnsavedSensitiveInputChanged = onUnsavedSensitiveInputChanged

        let draft = OnboardingDraftStore().load()
        let normalized = Self.normalizedProfiles(from: draft?.profiles ?? snapshot.providerProfiles)
        _profiles = State(initialValue: normalized)
        _preferences = State(initialValue: draft?.preferences ?? snapshot.userPreferences)
        let preselected = draft?.selectedProviders ?? Set(normalized.filter { $0.isEnabled }.map { $0.providerId })
        _selectedProviders = State(initialValue: preselected)
        _currentIndex = State(initialValue: draft?.currentIndex ?? 0)
        _claudeCredentialsSaved = State(initialValue: Self.hasConfiguredClaudeAccount(claudeAccounts))
        _claudeCredentialDraft = State(initialValue: Self.initialClaudeCredentialDraft(from: claudeAccounts))
        _savedClaudeAccountIds = State(initialValue: Set(claudeAccounts.map(\.accountId)))
        _codexSetupState = State(initialValue: codexSetupState)
    }

    private var steps: [OnboardingWizardStep] {
        OnboardingWizardStepSequencer.steps(for: selectedProviders)
    }

    private var clampedIndex: Int {
        min(max(currentIndex, 0), steps.count - 1)
    }

    private var currentStep: OnboardingWizardStep {
        steps[clampedIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressBar
            ScrollViewReader { proxy in
                ScrollView {
                    stepContent {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(OnboardingScrollTarget.claudeCredentialHelp, anchor: .bottom)
                        }
                    }
                    .padding(.trailing, 6)
                    .padding(.top, 4)
                }
            }
            footer
        }
        .padding(18)
        .frame(width: 520, height: 580, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.3), value: selectedProviders)
        .onChange(of: selectedProviders) { _ in saveDraft() }
        .onChange(of: profiles) { _ in saveDraft() }
        .onChange(of: preferences) { _ in saveDraft() }
        .onChange(of: currentIndex) { _ in saveDraft() }
        .onAppear { saveDraft() }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set Up Pitwall")
                .font(.system(size: 18, weight: .semibold))
            PitRoadProgressView(
                currentStep: currentStep,
                completedSteps: completedSteps,
                selectedProviders: selectedProviders
            )
        }
    }

    @ViewBuilder
    private func stepContent(onScrollToClaudeHelp: @escaping () -> Void) -> some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .toolSelection:
            ToolSelectionStepView(selectedProviders: $selectedProviders)
        case .credentials(.claude):
            ClaudeCredentialStepView(
                accounts: claudeAccounts,
                credentialDraft: $claudeCredentialDraft,
                onSaveClaudeCredentials: onSaveClaudeCredentials,
                onTestClaudeConnection: onTestClaudeConnection,
                onHelpExpanded: onScrollToClaudeHelp,
                onSensitiveInputChanged: onUnsavedSensitiveInputChanged
            )
        case .credentials(.codex):
            CodexCredentialStepView(
                profile: codexProfileBinding,
                setupState: $codexSetupState,
                onStartChatGPTLogin: onStartCodexChatGPTLogin,
                onCurrentChatGPTLoginState: onCurrentCodexChatGPTLoginState,
                onRetryChatGPTLoginBrowser: onRetryCodexChatGPTLoginBrowser,
                onCancelChatGPTLogin: onCancelCodexChatGPTLogin,
                onConnectAPIKey: onConnectCodexAPIKey,
                onDisconnect: onDisconnectCodex,
                onRefreshStatus: onRefreshCodexStatus,
                onSensitiveInputChanged: onUnsavedSensitiveInputChanged
            )
        case .credentials(let providerId):
            GenericProviderStepView(providerId: providerId, profiles: $profiles)
        case .preferences:
            PreferencesStepView(preferences: $preferences)
        case .summary:
            WizardSummaryStepView(
                selectedProviders: selectedProviders,
                preferences: preferences,
                claudeAccountCount: savedClaudeAccountIds.count
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Back") {
                currentIndex = max(0, clampedIndex - 1)
            }
            .disabled(clampedIndex == 0 || isSaving)

            if let busyMessage {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(busyMessage)
                    footerMessage(busyMessage)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(busyMessage)
            } else if let message {
                footerMessage(message)
            } else if let validationMessage {
                footerMessage(validationMessage)
            }

            Spacer()

            Button("Don't show again") {
                Task { await finish(skipped: true) }
            }
            .disabled(isSaving)

            Button(isLastStep ? "Finish" : "Continue") {
                Task {
                    if isLastStep {
                        await finish(skipped: false)
                    } else {
                        await continueFromCurrentStep()
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || !canAdvance)
        }
        .buttonStyle(.bordered)
    }

    private var isLastStep: Bool { currentStep == .summary }

    private func footerMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .toolSelection:
            return !selectedProviders.isEmpty
        case .credentials(.claude):
            return claudeCanAdvance
        case .credentials(.codex):
            return codexCanAdvance
        case .credentials(let providerId):
            return profileIsComplete(for: providerId)
        default:
            return true
        }
    }

    private var validationMessage: String? {
        switch currentStep {
        case .credentials(.claude) where !claudeCanAdvance:
            return "Enter a Claude org id and session key to continue."
        case .credentials(.codex) where !codexCanAdvance:
            return "Finish a Codex CLI login and verify the status to continue."
        case .credentials(let providerId) where !profileIsComplete(for: providerId):
            return "Enter the required \(displayName(for: providerId)) values to continue."
        default:
            return nil
        }
    }

    private var claudeCanAdvance: Bool {
        if claudeCredentialDraft.canSave {
            return true
        }

        return claudeCredentialsSaved && claudeCredentialDraft.sessionKey.isEmpty
    }

    private var codexCanAdvance: Bool {
        codexSetupState.status == .configured
    }

    private func continueFromCurrentStep() async {
        if currentStep == .credentials(.claude) {
            guard await saveAndCheckClaudeIfNeeded() else { return }
        }

        completedSteps.insert(currentStep)
        currentIndex = min(steps.count - 1, clampedIndex + 1)
    }

    private func saveAndCheckClaudeIfNeeded() async -> Bool {
        guard claudeCredentialDraft.canSave else {
            return claudeCredentialsSaved
        }

        isSaving = true
        message = nil
        busyMessage = "Saving Claude credentials..."
        defer {
            isSaving = false
            busyMessage = nil
        }

        let input = claudeCredentialDraft.input
        if let error = await onSaveClaudeCredentials(input) {
            message = error
            return false
        }

        claudeCredentialDraft.clearSensitiveFields()
        onUnsavedSensitiveInputChanged(false)

        busyMessage = "Testing Claude configuration..."
        let outcome = await onTestClaudeConnection(input.accountId)
        message = outcome.message
        claudeCredentialsSaved = outcome.canContinue
        if outcome.canContinue {
            savedClaudeAccountIds.insert(input.accountId)
        }
        return outcome.canContinue
    }

    private func finish(skipped: Bool) async {
        isSaving = true
        defer { isSaving = false }

        var outgoing = Self.normalizedProfiles(from: profiles)
        outgoing = outgoing.map { profile in
            var profile = profile
            if skipped {
                profile.isEnabled = false
            } else {
                profile.isEnabled = selectedProviders.contains(profile.providerId)
            }
            return profile
        }

        let snapshot = ProviderConfigurationSnapshot(
            providerProfiles: outgoing,
            claudeAccounts: [],
            selectedClaudeAccountId: nil,
            userPreferences: preferences
        )

        if let error = await onSaveConfiguration(snapshot) {
            message = error
        } else {
            OnboardingDraftStore().clear()
            onUnsavedSensitiveInputChanged(false)
            onFinish()
        }
    }

    private func saveDraft() {
        OnboardingDraftStore().save(
            OnboardingDraft(
                profiles: profiles,
                preferences: preferences,
                selectedProviders: selectedProviders,
                currentIndex: clampedIndex
            )
        )
    }

    private static func normalizedProfiles(
        from profiles: [ProviderProfileConfiguration]
    ) -> [ProviderProfileConfiguration] {
        PitwallAppSupport.supportedProviders.map { providerId in
            profiles.first(where: { $0.providerId == providerId }) ?? ProviderProfileConfiguration(providerId: providerId)
        }
    }

    private static func hasConfiguredClaudeAccount(_ accounts: [ClaudeAccountSetupState]) -> Bool {
        accounts.contains { account in
            account.isEnabled
                && !account.organizationId.trimmed.isEmpty
                && account.secretState.status == .configured
        }
    }

    private static func initialClaudeCredentialDraft(
        from accounts: [ClaudeAccountSetupState]
    ) -> ClaudeCredentialDraft {
        guard let account = accounts.first else {
            return ClaudeCredentialDraft()
        }

        return ClaudeCredentialDraft(
            accountId: account.accountId,
            label: account.label,
            organizationId: account.organizationId
        )
    }

    private func profileIsComplete(for providerId: ProviderID) -> Bool {
        if providerId == .codex {
            return codexCanAdvance
        }
        guard let profile = profiles.first(where: { $0.providerId == providerId }) else { return false }
        return !(profile.planProfile ?? "").trimmed.isEmpty
            && !(profile.authMode ?? "").trimmed.isEmpty
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

    private func displayName(for providerId: ProviderID) -> String {
        switch providerId {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        default: return providerId.rawValue.capitalized
        }
    }
}

enum OnboardingScrollTarget: Hashable {
    case claudeCredentialHelp
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
