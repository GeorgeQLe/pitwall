import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ClaudeConnectionTestOutcome: Equatable, Sendable {
    var message: String
    var canContinue: Bool

    static func unavailable(_ message: String) -> ClaudeConnectionTestOutcome {
        ClaudeConnectionTestOutcome(message: message, canContinue: false)
    }
}

struct ClaudeCredentialDraft: Equatable {
    var accountId: String
    var label: String
    var organizationId: String
    var sessionKey: String

    init(
        accountId: String = UUID().uuidString,
        label: String = "",
        organizationId: String = "",
        sessionKey: String = ""
    ) {
        self.accountId = accountId
        self.label = label
        self.organizationId = organizationId
        self.sessionKey = sessionKey
    }

    var canSave: Bool {
        !organizationId.trimmed.isEmpty && !sessionKey.isEmpty
    }

    var input: ClaudeCredentialInput {
        ClaudeCredentialInput(
            accountId: accountId,
            label: displayLabel,
            organizationId: organizationId.trimmed,
            sessionKey: sessionKey
        )
    }

    mutating func apply(_ account: ClaudeAccountSetupState) {
        accountId = account.accountId
        label = account.label
        organizationId = account.organizationId
        sessionKey = ""
    }

    mutating func clearSensitiveFields() {
        sessionKey = ""
    }

    private var displayLabel: String {
        let trimmedLabel = label.trimmed
        if !trimmedLabel.isEmpty {
            return trimmedLabel
        }

        let trimmedOrganizationId = organizationId.trimmed
        if !trimmedOrganizationId.isEmpty {
            return trimmedOrganizationId
        }

        return "Claude account"
    }
}

struct ClaudeCredentialSetupView: View {
    let accounts: [ClaudeAccountSetupState]
    @Binding var draft: ClaudeCredentialDraft
    let onSave: (ClaudeCredentialInput) async -> String?
    let onDelete: (String) async -> String?
    let onTest: (String?) async -> ClaudeConnectionTestOutcome
    var showsInlineActions = true
    var allowsAccountDeletion = true
    var onSaveSucceeded: () -> Void = {}
    var onSensitiveInputChanged: (Bool) -> Void = { _ in }

    @State private var selectedAccountId: String?
    @State private var message: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            savedAccounts
            credentialFields
            actions
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Credentials")
                .font(.system(size: 14, weight: .semibold))
            Text("Paste the Claude sessionKey and lastActiveOrg values manually. The session key is sensitive and is stored locally through the secret store; saved values are never rendered back into this field.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var savedAccounts: some View {
        VStack(alignment: .leading, spacing: 6) {
            if accounts.isEmpty {
                StatusBadgeView(text: "No Claude account saved", style: .warning)
            } else {
                ForEach(accounts, id: \.accountId) { account in
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.label)
                                .font(.system(size: 12, weight: .medium))
                            Text(account.organizationId)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        StatusBadgeView(text: statusText(for: account), style: badgeStyle(for: account))

                        Button("Use") {
                            selectedAccountId = account.accountId
                            draft.apply(account)
                            onSensitiveInputChanged(false)
                        }
                        .controlSize(.small)

                        if allowsAccountDeletion {
                            Button("Delete") {
                                Task { await delete(account.accountId) }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var credentialFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("Label (optional)")
                    .font(.system(size: 12, weight: .medium))
                TextField("Claude account", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Org id")
                    .font(.system(size: 12, weight: .medium))
                TextField("lastActiveOrg", text: $draft.organizationId)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Session key")
                    .font(.system(size: 12, weight: .medium))
                SecureField("sessionKey", text: $draft.sessionKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.sessionKey) { newValue in
                        onSensitiveInputChanged(!newValue.isEmpty)
                    }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsInlineActions {
                HStack(spacing: 8) {
                    Button("Save Credentials") {
                        Task { await save() }
                    }
                    .disabled(isBusy || !draft.canSave)

                    Button("Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(isBusy || accounts.isEmpty && selectedAccountId == nil)

                    Spacer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }

        let input = draft.input

        if let error = await onSave(input) {
            message = error
        } else {
            selectedAccountId = input.accountId
            draft.clearSensitiveFields()
            message = "Claude credentials saved. The session key field was cleared."
            onSensitiveInputChanged(false)
            onSaveSucceeded()
        }
    }

    private func delete(_ accountId: String) async {
        isBusy = true
        defer { isBusy = false }

        if let error = await onDelete(accountId) {
            message = error
        } else {
            message = "Claude account removed."
            if selectedAccountId == accountId {
                selectedAccountId = nil
            }
        }
    }

    private func testConnection() async {
        isBusy = true
        defer { isBusy = false }
        message = await onTest(selectedAccountId).message
    }

    private func statusText(for account: ClaudeAccountSetupState) -> String {
        switch account.secretState.status {
        case .configured:
            return "Configured"
        case .missing:
            return "Missing key"
        case .expired:
            return "Expired"
        }
    }

    private func badgeStyle(for account: ClaudeAccountSetupState) -> StatusBadgeView.Style {
        switch account.secretState.status {
        case .configured:
            return .success
        case .missing, .expired:
            return .warning
        }
    }

}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
