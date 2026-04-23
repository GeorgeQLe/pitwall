import PitwallAppSupport
import PitwallCore
import SwiftUI

struct GenericProviderStepView: View {
    let providerId: ProviderID
    @Binding var profiles: [ProviderProfileConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect \(displayName)")
                .font(.system(size: 18, weight: .semibold))

            Text("Direct credential sync for \(displayName) is not yet implemented. For now, record the plan you're on and how you authenticate — Pitwall will use this metadata in the menu bar display.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Plan or profile")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. Pro, Team", text: planProfileBinding)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Auth mode")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. ChatGPT login, API key", text: authModeBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    bullet("Plan or profile: the subscription tier or profile name you recognise (e.g. “Pro”, “Team workspace”).")
                    bullet("Auth mode: how you log in — ChatGPT SSO, API key, OAuth, etc.")
                    Text("Direct credential sync for \(displayName) is not yet implemented — tracked under Pitwall's post-v1 roadmap.")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 6)
            } label: {
                Text("What should I enter?")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var displayName: String {
        switch providerId {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        default: return providerId.rawValue.capitalized
        }
    }

    private var planProfileBinding: Binding<String> {
        Binding(
            get: { profile?.planProfile ?? "" },
            set: { newValue in
                updateProfile { $0.planProfile = newValue.trimmed.nilIfEmpty }
            }
        )
    }

    private var authModeBinding: Binding<String> {
        Binding(
            get: { profile?.authMode ?? "" },
            set: { newValue in
                updateProfile { $0.authMode = newValue.trimmed.nilIfEmpty }
            }
        )
    }

    private var profile: ProviderProfileConfiguration? {
        profiles.first(where: { $0.providerId == providerId })
    }

    private func updateProfile(_ mutate: (inout ProviderProfileConfiguration) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.providerId == providerId }) else { return }
        mutate(&profiles[index])
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.system(size: 12))
            Text(text).font(.system(size: 12))
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
