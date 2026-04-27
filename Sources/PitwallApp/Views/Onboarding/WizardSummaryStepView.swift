import PitwallAppSupport
import PitwallCore
import SwiftUI

struct WizardSummaryStepView: View {
    let selectedProviders: Set<ProviderID>
    let preferences: UserPreferences
    let claudeAccountCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You're all set")
                .font(.system(size: 18, weight: .semibold))

            Text("Review your choices below. Click Finish to start using Pitwall.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                section("Tools tracked", body: toolsSummary)
                section("Claude credentials", body: claudeSummary)
                section("Rotation", body: rotationSummary)
                section("Reset display", body: resetSummary)
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(body)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var toolsSummary: String {
        if selectedProviders.isEmpty { return "None — all providers are disabled." }
        return PitwallAppSupport.supportedProviders
            .filter { selectedProviders.contains($0) }
            .map(displayName(for:))
            .joined(separator: ", ")
    }

    private var claudeSummary: String {
        guard selectedProviders.contains(.claude) else { return "Not applicable — Claude is not selected." }
        if claudeAccountCount == 0 { return "No account saved yet — you can add credentials later from Settings." }
        return "\(claudeAccountCount) account\(claudeAccountCount == 1 ? "" : "s") saved."
    }

    private var rotationSummary: String {
        switch preferences.providerRotationMode {
        case .automatic: return "Rotate every \(Int(preferences.rotationInterval))s"
        case .pinned:
            let pinned = preferences.pinnedProviderId.map(displayName(for:)) ?? "Claude"
            return "Pinned to \(pinned)"
        case .paused: return "Paused"
        }
    }

    private var resetSummary: String {
        switch preferences.resetDisplayPreference {
        case .countdown: return "Countdown"
        case .resetTime: return "Reset time"
        }
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
