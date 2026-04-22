import PitwallAppSupport
import PitwallCore
import SwiftUI

struct GitHubHeatmapSettingsView: View {
    @Binding var settings: GitHubHeatmapSettings
    let onSaveToken: ((String, String) async -> GitHubHeatmapTokenStatus?)?

    @State private var pendingToken = ""
    @State private var message: String?
    @State private var isSavingToken = false

    init(
        settings: Binding<GitHubHeatmapSettings>,
        onSaveToken: ((String, String) async -> GitHubHeatmapTokenStatus?)? = nil
    ) {
        _settings = settings
        self.onSaveToken = onSaveToken
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GitHub Heatmap")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Show contribution heatmap", isOn: isEnabled)

            TextField("GitHub username", text: username)
                .textFieldStyle(.roundedBorder)
                .disabled(!settings.isEnabled)

            HStack(spacing: 8) {
                SecureField("Personal access token", text: $pendingToken)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!settings.isEnabled)

                Button("Save Token") {
                    Task { await saveToken() }
                }
                .disabled(!settings.isEnabled || pendingToken.isEmpty || settings.username.isEmpty || isSavingToken || onSaveToken == nil)
            }

            HStack(spacing: 10) {
                Text(tokenStatusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if let settingsDate = settings.lastRefreshAt {
                    Text("Last refresh: \(settingsDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { settings.isEnabled },
            set: { settings.isEnabled = $0 }
        )
    }

    private var username: Binding<String> {
        Binding(
            get: { settings.username },
            set: { settings.username = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
    }

    private var tokenStatusText: String {
        switch settings.tokenState {
        case .missing:
            return "Token missing"
        case .configured:
            return "Token saved"
        case .invalidOrExpired:
            return "Token invalid or expired"
        }
    }

    private func saveToken() async {
        guard let onSaveToken else {
            return
        }

        isSavingToken = true
        defer { isSavingToken = false }

        if let status = await onSaveToken(settings.username, pendingToken) {
            settings.tokenState = status
            pendingToken = ""
            message = "Token saved."
        } else {
            message = "Token could not be saved."
        }
    }
}
