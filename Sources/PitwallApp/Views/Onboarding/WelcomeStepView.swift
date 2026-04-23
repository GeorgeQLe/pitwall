import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome to Pitwall")
                .font(.system(size: 20, weight: .semibold))

            Text("Pitwall paces your AI coding subscriptions — Claude, Codex, and Gemini — against their daily and weekly limits so you never get surprised by a reset window.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This quick setup will:")
                .font(.system(size: 13, weight: .medium))
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Ask which AI coding tools you use")
                bullet("Walk you through connecting each one")
                bullet("Let you tune the menu bar display")
            }

            Spacer()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").font(.system(size: 13))
            Text(text).font(.system(size: 13))
        }
    }
}
