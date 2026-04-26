import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ClaudeCredentialStepView: View {
    let accounts: [ClaudeAccountSetupState]
    let onSaveClaudeCredentials: (ClaudeCredentialInput) async -> String?
    let onTestClaudeConnection: (String?) async -> String
    let onHelpExpanded: () -> Void
    let onCredentialsSaved: () -> Void
    let onSensitiveInputChanged: (Bool) -> Void
    @State private var isHelpExpanded = false

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
                onTest: onTestClaudeConnection,
                onSaveSucceeded: onCredentialsSaved,
                onSensitiveInputChanged: onSensitiveInputChanged
            )

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHelpExpanded.toggle()
                    }
                    if !isHelpExpanded {
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onHelpExpanded()
                    }
                } label: {
                    Label(
                        "How do I find these values?",
                        systemImage: isHelpExpanded ? "chevron.down.circle.fill" : "chevron.right.circle"
                    )
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .accessibilityHint(isHelpExpanded ? "Hide Claude credential instructions" : "Show Claude credential instructions")
                .zIndex(1)

                VStack(alignment: .leading, spacing: 8) {
                    if isHelpExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            instructionRow(1, "Open https://claude.ai in your browser and sign in.")
                            instructionRow(2, "Open DevTools with Option + Command + I.")
                            instructionRow(3, "Go to the Application tab, then Cookies, then https://claude.ai.")
                            instructionRow(4, "Copy the sessionKey value and paste it into the Session Key field above.")
                            instructionRow(5, "Copy the lastActiveOrg value and paste it into the Org Id field.")
                            instructionRow(6, "Give the account a label, such as Personal, so you can spot it later.")
                            Text("Tip: this wizard stays on screen while you switch to your browser.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.leading, 4)
                        .id(OnboardingScrollTarget.claudeCredentialHelp)
                        .transition(.move(edge: .top))
                    }
                }
                .clipped()
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
