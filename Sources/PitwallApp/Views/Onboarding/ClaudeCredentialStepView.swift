import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ClaudeCredentialStepView: View {
    let accounts: [ClaudeAccountSetupState]
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect Claude")
                .font(.system(size: 18, weight: .semibold))

            Text("Pitwall reads your Claude usage by replaying the same session cookie your browser uses. Nothing leaves your Mac — the session key is stored locally through the system secret store.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ClaudeCredentialSetupView(
                accounts: accounts,
                onSave: onSaveClaudeCredentials,
                onDelete: { _ in "Delete saved accounts from Settings." },
                onTest: onTestClaudeConnection
            )

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(1, "Open https://claude.ai in your browser and sign in.")
                    instructionRow(2, "Open DevTools with ⌥⌘I (Option + Command + I).")
                    instructionRow(3, "Go to the Application tab → Cookies → https://claude.ai.")
                    instructionRow(4, "Copy the sessionKey value and paste it into the Session Key field above.")
                    instructionRow(5, "Copy the lastActiveOrg value and paste it into the Org Id field.")
                    instructionRow(6, "Give the account a label (e.g. “Personal”) so you can spot it later.")
                    Text("Tip: this wizard stays on screen while you switch to your browser.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 6)
            } label: {
                Text("How do I find these values?")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private func instructionRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18, alignment: .trailing)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
