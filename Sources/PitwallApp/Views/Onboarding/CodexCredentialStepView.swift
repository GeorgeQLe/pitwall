import PitwallAppSupport
import SwiftUI

struct CodexCredentialStepView: View {
    @Binding var profile: ProviderProfileConfiguration
    @Binding var setupState: CodexSetupState
    let onStartChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onCurrentChatGPTLoginState: () async -> CodexDeviceAuthSessionState
    let onRetryChatGPTLoginBrowser: () async -> CodexDeviceAuthSessionState
    let onCancelChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onConnectAPIKey: (String) async -> CodexConnectionOutcome
    let onDisconnect: () async -> CodexConnectionOutcome
    let onRefreshStatus: () async -> CodexSetupState
    let onSensitiveInputChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect Codex")
                .font(.system(size: 18, weight: .semibold))

            Text("Pitwall verifies Codex through the official CLI login flow. Use ChatGPT sign-in to open the browser-first device flow here, or hand the CLI an API key without Pitwall storing it.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            CodexCredentialSetupView(
                profile: $profile,
                setupState: $setupState,
                onStartChatGPTLogin: onStartChatGPTLogin,
                onCurrentChatGPTLoginState: onCurrentChatGPTLoginState,
                onRetryChatGPTLoginBrowser: onRetryChatGPTLoginBrowser,
                onCancelChatGPTLogin: onCancelChatGPTLogin,
                onConnectAPIKey: onConnectAPIKey,
                onDisconnect: onDisconnect,
                onRefreshStatus: onRefreshStatus,
                onSensitiveInputChanged: onSensitiveInputChanged
            )
        }
    }
}
