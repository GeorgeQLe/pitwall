import PitwallAppSupport
import SwiftUI

struct CodexConnectionOutcome: Equatable, Sendable {
    var message: String
    var canContinue: Bool
    var setupState: CodexSetupState

    static func unavailable(_ message: String) -> CodexConnectionOutcome {
        CodexConnectionOutcome(
            message: message,
            canContinue: false,
            setupState: CodexSetupState(
                status: .unavailable,
                headline: "Codex CLI unavailable",
                detail: message
            )
        )
    }
}

struct CodexCredentialSetupView: View {
    @Binding var profile: ProviderProfileConfiguration
    @Binding var setupState: CodexSetupState
    let onStartChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onCurrentChatGPTLoginState: () async -> CodexDeviceAuthSessionState
    let onRetryChatGPTLoginBrowser: () async -> CodexDeviceAuthSessionState
    let onCancelChatGPTLogin: () async -> CodexDeviceAuthSessionState
    let onConnectAPIKey: (String) async -> CodexConnectionOutcome
    let onDisconnect: () async -> CodexConnectionOutcome
    let onRefreshStatus: () async -> CodexSetupState
    var onSensitiveInputChanged: (Bool) -> Void = { _ in }

    @State private var apiKey = ""
    @State private var message: String?
    @State private var isBusy = false
    @State private var loginState = CodexDeviceAuthSessionState.idle

    private let pollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modePicker
            statusSummary
            planProfileField
            setupActions
        }
        .task {
            await refreshChatGPTLoginState()
        }
        .onReceive(pollTimer) { _ in
            guard selectedAuthMode == .chatgpt, loginState.isActive else {
                return
            }
            Task { await refreshChatGPTLoginState() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codex Connection")
                .font(.system(size: 14, weight: .semibold))
            Text("Pitwall uses the supported Codex CLI login flow. ChatGPT sign-in stays owned by the CLI, and API-key setup is handed to the CLI without Pitwall storing the key.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        Picker("Codex auth", selection: authModeBinding) {
            ForEach(CodexAuthMode.allCases, id: \.self) { mode in
                Text(mode == .chatgpt ? "ChatGPT sign-in" : "API key").tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(setupState.headline)
                    .font(.system(size: 12, weight: .medium))
                StatusBadgeView(text: badgeText, style: badgeStyle)
            }
            Text(setupState.detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planProfileField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan or profile (optional)")
                .font(.system(size: 12, weight: .medium))
            TextField("e.g. Plus, Pro, Team", text: planProfileBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var setupActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch selectedAuthMode {
            case .chatgpt:
                chatGPTActions
            case .apiKey:
                apiKeyActions
            }

            if setupState.status == .configured {
                Button("Disconnect") {
                    Task { await disconnect() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isBusy || loginState.isActive)

                Text("Disconnecting logs Codex out locally. CLI-generated API keys may still need manual revocation from the OpenAI API dashboard.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var chatGPTActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(loginState.isActive ? "Connecting…" : "Connect with ChatGPT") {
                    Task { await startChatGPTLogin() }
                }
                .disabled(isBusy || loginState.isActive)

                if loginState.verificationURL != nil && !loginState.didOpenBrowser {
                    Button("Retry Open Browser") {
                        Task { await retryOpenBrowser() }
                    }
                    .disabled(isBusy)
                }

                if loginState.canCancel {
                    Button("Cancel") {
                        Task { await cancelChatGPTLogin() }
                    }
                    .disabled(isBusy)
                } else {
                    Button("Check Status") {
                        Task { await refreshStatus() }
                    }
                    .disabled(isBusy || loginState.isActive)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Pitwall starts the official Codex device-auth flow, opens your browser, shows the one-time code here, and updates when the CLI confirms login.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if loginState.phase != .idle {
                chatGPTProgress
            }
        }
    }

    private var chatGPTProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loginState.message)
                .font(.system(size: 12, weight: .medium))

            if let deviceCode = loginState.deviceCode {
                VStack(alignment: .leading, spacing: 2) {
                    Text("One-time code")
                        .font(.system(size: 11, weight: .medium))
                    Text(deviceCode)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let verificationURL = loginState.verificationURL {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loginState.didOpenBrowser ? "Browser link" : "Open this URL if your browser did not open")
                        .font(.system(size: 11, weight: .medium))
                    Text(verificationURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var apiKeyActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("OpenAI API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { newValue in
                    onSensitiveInputChanged(!newValue.isEmpty)
                }

            HStack(spacing: 8) {
                Button("Connect API Key") {
                    Task { await connectAPIKey() }
                }
                .disabled(isBusy || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Check Status") {
                    Task { await refreshStatus() }
                }
                .disabled(isBusy)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var selectedAuthMode: CodexAuthMode {
        CodexAuthMode(rawValue: profile.authMode ?? "")
            ?? setupState.authMode
            ?? .chatgpt
    }

    private var authModeBinding: Binding<CodexAuthMode> {
        Binding(
            get: { selectedAuthMode },
            set: { profile.authMode = $0.rawValue }
        )
    }

    private var planProfileBinding: Binding<String> {
        Binding(
            get: { profile.planProfile ?? "" },
            set: { profile.planProfile = $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        )
    }

    private var badgeText: String {
        switch setupState.status {
        case .configured:
            return "Configured"
        case .missing:
            return "Missing setup"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var badgeStyle: StatusBadgeView.Style {
        switch setupState.status {
        case .configured:
            return .success
        case .missing:
            return .warning
        case .unavailable:
            return .critical
        }
    }

    private func startChatGPTLogin() async {
        isBusy = true
        defer { isBusy = false }
        apply(loginState: await onStartChatGPTLogin())
    }

    private func retryOpenBrowser() async {
        isBusy = true
        defer { isBusy = false }
        apply(loginState: await onRetryChatGPTLoginBrowser())
    }

    private func cancelChatGPTLogin() async {
        isBusy = true
        defer { isBusy = false }
        apply(loginState: await onCancelChatGPTLogin())
    }

    private func refreshChatGPTLoginState() async {
        apply(loginState: await onCurrentChatGPTLoginState())
    }

    private func connectAPIKey() async {
        isBusy = true
        defer { isBusy = false }

        let outcome = await onConnectAPIKey(apiKey)
        setupState = outcome.setupState
        message = outcome.message
        apiKey = ""
        onSensitiveInputChanged(false)
        if let authMode = outcome.setupState.authMode {
            profile.authMode = authMode.rawValue
        }
    }

    private func disconnect() async {
        isBusy = true
        defer { isBusy = false }

        let outcome = await onDisconnect()
        setupState = outcome.setupState
        message = outcome.message
        loginState = .idle
    }

    private func refreshStatus() async {
        isBusy = true
        defer { isBusy = false }

        let refreshed = await onRefreshStatus()
        setupState = refreshed
        if let authMode = refreshed.authMode {
            profile.authMode = authMode.rawValue
        }
        message = refreshed.status == .configured
            ? "Codex connection verified."
            : refreshed.detail
    }

    private func apply(loginState: CodexDeviceAuthSessionState) {
        self.loginState = loginState
        if let finalSetupState = loginState.finalSetupState {
            setupState = finalSetupState
            if let authMode = finalSetupState.authMode {
                profile.authMode = authMode.rawValue
            }
        }

        message = loginState.phase == .idle ? nil : loginState.message
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
