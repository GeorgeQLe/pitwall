import PitwallAppSupport
import SwiftUI

struct GeminiCredentialSetupView: View {
    @Binding var profile: ProviderProfileConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Toggle(isOn: telemetryEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Use Gemini CLI Google login for quota telemetry")
                        .font(.system(size: 12, weight: .medium))
                    Text("Pitwall reads the existing Gemini CLI OAuth cache only after this is enabled. Raw Google tokens are not stored by Pitwall.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            planProfileField
            statusText
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gemini Connection")
                .font(.system(size: 14, weight: .semibold))
            Text("Sign in with the Gemini CLI using Google login first. API-key and Vertex modes remain available for passive tracking, but exact quota telemetry requires the CLI OAuth login.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planProfileField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan or profile (optional)")
                .font(.system(size: 12, weight: .medium))
            TextField("e.g. Pro, Ultra, Work profile", text: planProfileBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var statusText: some View {
        let message = profile.telemetryEnabled
            ? "Telemetry will refresh from `~/.gemini` or `GEMINI_HOME` when Gemini uses Google login."
            : "Telemetry is off. Pitwall will continue showing passive Gemini local evidence."
        return Text(message)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var telemetryEnabled: Binding<Bool> {
        Binding(
            get: { profile.telemetryEnabled },
            set: { profile.telemetryEnabled = $0 }
        )
    }

    private var planProfileBinding: Binding<String> {
        Binding(
            get: { profile.planProfile ?? "" },
            set: { profile.planProfile = $0.trimmed.nilIfEmpty }
        )
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
