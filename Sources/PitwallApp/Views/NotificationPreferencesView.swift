import PitwallAppSupport
import PitwallCore
import SwiftUI

struct NotificationPreferencesView: View {
    @Binding var preferences: NotificationPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Claude session resets", isOn: resetNotificationsEnabled)
            Toggle("Expired authentication", isOn: expiredAuthNotificationsEnabled)
            Toggle("Telemetry degraded", isOn: telemetryDegradedNotificationsEnabled)
            Toggle("Pacing threshold", isOn: pacingThresholdNotificationsEnabled)

            Picker("Threshold", selection: pacingThreshold) {
                Text("Warning").tag(PacingLabel.warning)
                Text("Critical").tag(PacingLabel.critical)
                Text("Capped").tag(PacingLabel.capped)
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.pacingThresholdNotificationsEnabled)
        }
    }

    private var resetNotificationsEnabled: Binding<Bool> {
        Binding(
            get: { preferences.resetNotificationsEnabled },
            set: { preferences.resetNotificationsEnabled = $0 }
        )
    }

    private var expiredAuthNotificationsEnabled: Binding<Bool> {
        Binding(
            get: { preferences.expiredAuthNotificationsEnabled },
            set: { preferences.expiredAuthNotificationsEnabled = $0 }
        )
    }

    private var telemetryDegradedNotificationsEnabled: Binding<Bool> {
        Binding(
            get: { preferences.telemetryDegradedNotificationsEnabled },
            set: { preferences.telemetryDegradedNotificationsEnabled = $0 }
        )
    }

    private var pacingThresholdNotificationsEnabled: Binding<Bool> {
        Binding(
            get: { preferences.pacingThresholdNotificationsEnabled },
            set: { preferences.pacingThresholdNotificationsEnabled = $0 }
        )
    }

    private var pacingThreshold: Binding<PacingLabel> {
        Binding(
            get: { preferences.pacingThreshold },
            set: { preferences.pacingThreshold = $0 }
        )
    }
}
