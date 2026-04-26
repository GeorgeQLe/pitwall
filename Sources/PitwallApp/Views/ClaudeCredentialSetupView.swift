import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ClaudeCredentialSetupView: View {
    let accounts: [ClaudeAccountSetupState]
    let onSave: (ClaudeCredentialInput) async -> String?
    let onDelete: (String) async -> String?
    let onTest: (String?) async -> String
    var onSaveSucceeded: () -> Void = {}
    var onSensitiveInputChanged: (Bool) -> Void = { _ in }

    @State private var accountId = UUID().uuidString
    @State private var label = ""
    @State private var organizationId = ""
    @State private var sessionKey = ""
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
                            accountId = account.accountId
                            label = account.label
                            organizationId = account.organizationId
                            sessionKey = ""
                        }
                        .controlSize(.small)

                        Button("Delete") {
                            Task { await delete(account.accountId) }
                        }
                        .controlSize(.small)
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
                TextField("Claude account", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Org id")
                    .font(.system(size: 12, weight: .medium))
                TextField("lastActiveOrg", text: $organizationId)
                    .textFieldStyle(.roundedBorder)
            }

            GridRow {
                Text("Session key")
                    .font(.system(size: 12, weight: .medium))
                SecureField("sessionKey", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: sessionKey) { newValue in
                        onSensitiveInputChanged(!newValue.isEmpty)
                    }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Save Credentials") {
                    Task { await save() }
                }
                .disabled(isBusy || organizationId.trimmed.isEmpty || sessionKey.isEmpty)

                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(isBusy || accounts.isEmpty && selectedAccountId == nil)

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

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

        let input = ClaudeCredentialInput(
            accountId: accountId,
            label: displayLabel,
            organizationId: organizationId.trimmed,
            sessionKey: sessionKey
        )

        if let error = await onSave(input) {
            message = error
        } else {
            selectedAccountId = input.accountId
            sessionKey = ""
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
        message = await onTest(selectedAccountId)
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

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
