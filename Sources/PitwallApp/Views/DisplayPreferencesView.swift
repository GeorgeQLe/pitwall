import PitwallAppSupport
import PitwallCore
import SwiftUI

struct DisplayPreferencesView: View {
    @Binding var preferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display")
                .font(.system(size: 14, weight: .semibold))

            Picker("Reset display", selection: resetDisplayPreference) {
                Text("Countdown").tag(ResetDisplayPreference.countdown)
                Text("Reset time").tag(ResetDisplayPreference.resetTime)
            }
            .pickerStyle(.segmented)

            Picker("Claude tray theme", selection: menuBarTheme) {
                ForEach(MenuBarTheme.allCases, id: \.self) { theme in
                    Text(themeLabel(for: theme)).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tray rotation", selection: providerRotationMode) {
                Text("Rotate").tag(ProviderRotationMode.automatic)
                Text("Pin").tag(ProviderRotationMode.pinned)
                Text("Pause").tag(ProviderRotationMode.paused)
            }
            .pickerStyle(.segmented)

            if preferences.providerRotationMode == .pinned {
                Picker("Pinned provider", selection: pinnedProviderId) {
                    Text("Claude").tag(Optional(ProviderID.claude))
                    Text("Codex").tag(Optional(ProviderID.codex))
                    Text("Gemini").tag(Optional(ProviderID.gemini))
                }
            }

            HStack {
                Text("Rotation interval")
                    .font(.system(size: 12, weight: .medium))
                Slider(value: rotationInterval, in: 5...10, step: 1)
                Text("\(Int(preferences.rotationInterval))s")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    private var resetDisplayPreference: Binding<ResetDisplayPreference> {
        Binding(
            get: { preferences.resetDisplayPreference },
            set: { preferences.resetDisplayPreference = $0 }
        )
    }

    private var providerRotationMode: Binding<ProviderRotationMode> {
        Binding(
            get: { preferences.providerRotationMode },
            set: {
                preferences.providerRotationMode = $0
                if $0 == .pinned, preferences.pinnedProviderId == nil {
                    preferences.pinnedProviderId = .claude
                }
            }
        )
    }

    private var pinnedProviderId: Binding<ProviderID?> {
        Binding(
            get: { preferences.pinnedProviderId },
            set: { preferences.pinnedProviderId = $0 }
        )
    }

    private var rotationInterval: Binding<Double> {
        Binding(
            get: { preferences.rotationInterval },
            set: { preferences.rotationInterval = $0 }
        )
    }

    private var menuBarTheme: Binding<MenuBarTheme> {
        Binding(
            get: { preferences.menuBarTheme },
            set: { preferences.menuBarTheme = $0 }
        )
    }

    private func themeLabel(for theme: MenuBarTheme) -> String {
        switch theme {
        case .running:
            return "Running 🚶"
        case .racecar:
            return "Racecar 🏎️"
        case .f1Quali:
            return "F1 Quali 🟣"
        }
    }
}
