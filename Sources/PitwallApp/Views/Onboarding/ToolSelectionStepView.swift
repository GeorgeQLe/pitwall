import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ToolSelectionStepView: View {
    @Binding var selectedProviders: Set<ProviderID>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which tools do you use?")
                .font(.system(size: 18, weight: .semibold))

            Text("Pick every AI coding subscription you want Pitwall to track. You can change this later in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(PitwallAppSupport.supportedProviders, id: \.self) { providerId in
                    Toggle(isOn: binding(for: providerId)) {
                        VStack(alignment: .leading, spacing: 2) {
                            ProviderBrandView(
                                providerId: providerId,
                                displayName: displayName(for: providerId),
                                style: .row
                            )
                            Text(subtitle(for: providerId))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)

            if selectedProviders.isEmpty {
                Text("Select at least one tool to continue, or use Skip setup to finish with everything disabled.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            Spacer()
        }
    }

    private func binding(for providerId: ProviderID) -> Binding<Bool> {
        Binding(
            get: { selectedProviders.contains(providerId) },
            set: { isOn in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if isOn {
                        selectedProviders.insert(providerId)
                    } else {
                        selectedProviders.remove(providerId)
                    }
                }
            }
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

    private func subtitle(for providerId: ProviderID) -> String {
        switch providerId {
        case .claude: return "Anthropic Claude subscription (Pro, Max, or Team)"
        case .codex: return "OpenAI Codex / ChatGPT coding plan"
        case .gemini: return "Google Gemini Code Assist"
        default: return ""
        }
    }
}
