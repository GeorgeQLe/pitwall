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

        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: binding.isEnabled) {
                HStack {
                    Text(displayName(for: providerId))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(binding.wrappedValue.isEnabled ? "Visible" : "Skipped")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                TextField("Plan or profile", text: binding.planProfile)
                authModeControl(for: providerId, binding: binding.authMode)
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))
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

    @ViewBuilder
    private func authModeControl(for providerId: ProviderID, binding: Binding<String>) -> some View {
        if providerId == .codex {
            Picker("Auth mode", selection: binding) {
                Text("Select auth mode").tag("")
                ForEach(codexAuthModes, id: \.self) { mode in
                    Text(mode).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        } else {
            TextField("Auth mode", text: binding)
        }
    }

    private var codexAuthModes: [String] {
        ["ChatGPT login", "API key"]
    }
}

private extension Binding where Value == ProviderProfileConfiguration {
    var isEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.isEnabled },
            set: { wrappedValue.isEnabled = $0 }
        )
    }

    var planProfile: Binding<String> {
        Binding<String>(
            get: { wrappedValue.planProfile ?? "" },
            set: { wrappedValue.planProfile = $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        )
    }

    var authMode: Binding<String> {
        Binding<String>(
            get: { wrappedValue.authMode ?? "" },
            set: { wrappedValue.authMode = $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
