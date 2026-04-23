import PitwallAppSupport
import PitwallCore
import SwiftUI

struct PreferencesStepView: View {
    @Binding var preferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Menu bar display")
                .font(.system(size: 18, weight: .semibold))

            Text("How should Pitwall show usage in your menu bar? You can change any of this later.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisplayPreferencesView(preferences: $preferences)

            Spacer()
        }
    }
}
