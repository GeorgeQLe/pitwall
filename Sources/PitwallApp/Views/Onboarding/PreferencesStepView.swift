import PitwallAppSupport
import PitwallCore
import SwiftUI

struct PreferencesStepView: View {
    @Binding var preferences: UserPreferences
    let loginItemService: LoginItemService?

    @State private var launchAtLoginEnabled: Bool
    @State private var launchAtLoginMessage: String?

    init(preferences: Binding<UserPreferences>, loginItemService: LoginItemService?) {
        self._preferences = preferences
        self.loginItemService = loginItemService
        _launchAtLoginEnabled = State(initialValue: loginItemService?.isEnabled ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.system(size: 18, weight: .semibold))

            Text("Configure how Pitwall behaves. You can change any of this later.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Startup")
                    .font(.system(size: 13, weight: .semibold))
                Toggle("Launch Pitwall at login", isOn: launchAtLoginBinding)
                    .disabled(loginItemService == nil)
                if let launchAtLoginMessage {
                    Text(launchAtLoginMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Menu bar display")
                    .font(.system(size: 13, weight: .semibold))
                DisplayPreferencesView(preferences: $preferences)
            }

            Spacer()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { newValue in
                guard let service = loginItemService else {
                    launchAtLoginEnabled = newValue
                    return
                }
                do {
                    try service.setEnabled(newValue)
                    launchAtLoginEnabled = service.isEnabled
                    launchAtLoginMessage = nil
                } catch {
                    launchAtLoginEnabled = service.isEnabled
                    launchAtLoginMessage = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        )
    }
}
