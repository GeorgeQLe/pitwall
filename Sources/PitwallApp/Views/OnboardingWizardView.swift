import PitwallAppSupport
import PitwallCore
import SwiftUI

struct OnboardingWizardView: View {
    let claudeAccounts: [ClaudeAccountSetupState]
    let onSaveConfiguration: (ProviderConfigurationSnapshot) async -> String?
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onFinish: () -> Void

    @State private var profiles: [ProviderProfileConfiguration]
    @State private var preferences: UserPreferences
    @State private var selectedProviders: Set<ProviderID>
    @State private var currentIndex: Int = 0
    @State private var message: String?
    @State private var isSaving = false
    @State private var completedSteps: Set<OnboardingWizardStep> = []
    @State private var claudeCredentialsSaved: Bool

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
        let normalized = Self.normalizedProfiles(from: snapshot.providerProfiles)
        _profiles = State(initialValue: normalized)
        _preferences = State(initialValue: snapshot.userPreferences)
        let preselected = Set(normalized.filter { $0.isEnabled }.map { $0.providerId })
        _selectedProviders = State(initialValue: preselected)
        _claudeCredentialsSaved = State(initialValue: Self.hasConfiguredClaudeAccount(claudeAccounts))
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
                onSaveClaudeCredentials: onSaveClaudeCredentials,
                onTestClaudeConnection: onTestClaudeConnection,
                onHelpExpanded: onScrollToClaudeHelp,
                onCredentialsSaved: {
                    claudeCredentialsSaved = true
                    message = nil
                }
            )
        case .credentials(let providerId):
            GenericProviderStepView(providerId: providerId, profiles: $profiles)
        case .preferences:
            PreferencesStepView(preferences: $preferences)
        case .summary:
            WizardSummaryStepView(
                selectedProviders: selectedProviders,
                preferences: preferences,
                claudeAccounts: claudeAccounts
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Back") {
                currentIndex = max(0, clampedIndex - 1)
            }
            .disabled(clampedIndex == 0 || isSaving)

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Button("Don't show again") {
                Task { await finish(skipped: true) }
            }
            .disabled(isSaving)

            Button(isLastStep ? "Finish" : "Continue") {
                if isLastStep {
                    Task { await finish(skipped: false) }
                } else {
                    completedSteps.insert(currentStep)
                    currentIndex = min(steps.count - 1, clampedIndex + 1)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || !canAdvance)
        }
        .buttonStyle(.bordered)
    }

    private var isLastStep: Bool { currentStep == .summary }

    private var canAdvance: Bool {
        switch currentStep {
        case .toolSelection:
            return !selectedProviders.isEmpty
        case .credentials(.claude):
            return claudeCredentialsSaved
        case .credentials(let providerId):
            return profileIsComplete(for: providerId)
        default:
            return true
        }
    }

    private var validationMessage: String? {
        switch currentStep {
        case .credentials(.claude) where !claudeCredentialsSaved:
            return "Save a Claude org id and session key to continue."
        case .credentials(let providerId) where !profileIsComplete(for: providerId):
            return "Enter the required \(displayName(for: providerId)) values to continue."
        default:
            return nil
        }
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

    private static func hasConfiguredClaudeAccount(_ accounts: [ClaudeAccountSetupState]) -> Bool {
        accounts.contains { account in
            account.isEnabled
                && !account.organizationId.trimmed.isEmpty
                && account.secretState.status == .configured
        }
    }

    private func profileIsComplete(for providerId: ProviderID) -> Bool {
        guard let profile = profiles.first(where: { $0.providerId == providerId }) else { return false }
        return !(profile.planProfile ?? "").trimmed.isEmpty
            && !(profile.authMode ?? "").trimmed.isEmpty
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
