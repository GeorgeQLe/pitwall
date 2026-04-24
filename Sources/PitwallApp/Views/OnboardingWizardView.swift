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
            ScrollView {
                stepContent
                    .padding(.trailing, 6)
                    .padding(.top, 4)
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
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .toolSelection:
            ToolSelectionStepView(selectedProviders: $selectedProviders)
        case .credentials(.claude):
            ClaudeCredentialStepView(
                accounts: claudeAccounts,
                onSaveClaudeCredentials: onSaveClaudeCredentials,
                onTestClaudeConnection: onTestClaudeConnection
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
        default:
            return true
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
}
