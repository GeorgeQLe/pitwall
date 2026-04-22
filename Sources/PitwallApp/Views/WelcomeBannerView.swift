import SwiftUI

struct WelcomeBannerView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.wave.fill")
                    .foregroundStyle(.tint)
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Pitwall. You're replacing a previous menu bar app — Pitwall does not copy data from it.")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Paste your Claude `sessionKey` and `lastActiveOrg` in Settings → Claude account to get started.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("Secrets are stored in the macOS Keychain.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Dismiss welcome banner")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
