import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ProviderEnablementView: View {
    @Binding var profiles: [ProviderProfileConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Providers")
                .font(.system(size: 14, weight: .semibold))

            ForEach(PitwallAppSupport.supportedProviders, id: \.self) { providerId in
                providerRow(providerId)
            }
        }
    }

    private func providerRow(_ providerId: ProviderID) -> some View {
        let binding = binding(for: providerId)

        return Toggle(isOn: binding.isEnabled) {
            HStack {
                ProviderBrandView(
                    providerId: providerId,
                    displayName: displayName(for: providerId),
                    style: .row
                )
                Spacer()
                Text(binding.wrappedValue.isEnabled ? "Visible" : "Skipped")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .gemini:
            return "Gemini"
        default:
            return providerId.rawValue.capitalized
        }
    }

}

private extension Binding where Value == ProviderProfileConfiguration {
    var isEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.isEnabled },
            set: { wrappedValue.isEnabled = $0 }
        )
    }

}
