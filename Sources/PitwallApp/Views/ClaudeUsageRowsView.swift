import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ClaudeUsageRowsView: View {
    let provider: ProviderState
    let preferences: UserPreferences

    private var rows: [ClaudeUsageRow] {
        if let payload = provider.payloads.first(where: { $0.source == "usageRows" }) {
            return payload.values.keys.sorted().compactMap { key in
                guard let row = ClaudeUsageRow(label: key, encodedValue: payload.values[key] ?? "") else {
                    return nil
                }
                return row
            }
        }

        if let percent = provider.pacingState?.weeklyUtilizationPercent {
            return [
                ClaudeUsageRow(
                    label: "Weekly",
                    percent: percent,
                    resetText: ProviderCardViewModel(provider: provider, preferences: preferences).resetText ?? "Unknown",
                    status: provider.status == .configured ? "exact" : provider.status.rawValue
                )
            ]
        }

        return []
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        progress(percent: row.percent)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.label)
                                    .font(.system(size: 12, weight: .semibold))
                                StatusBadgeView(text: row.status.capitalized, style: .neutral)
                                Spacer()
                                Text("\(Int(row.percent.rounded()))%")
                                    .font(.system(size: 12, weight: .semibold))
                            }

                            ProgressView(value: min(max(row.percent, 0), 100), total: 100)
                                .progressViewStyle(.linear)

                            Text(row.resetText)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func progress(percent: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .separatorColor), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(percent / 100, 0), 1))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 30, height: 30)
    }
}

private struct ClaudeUsageRow: Identifiable {
    var id: String { label }
    let label: String
    let percent: Double
    let resetText: String
    let status: String

    init(label: String, percent: Double, resetText: String, status: String) {
        self.label = label
        self.percent = percent
        self.resetText = resetText
        self.status = status
    }

    init?(label: String, encodedValue: String) {
        let parts = encodedValue.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3, let percent = Double(parts[0]) else {
            return nil
        }

        self.label = label
        self.percent = percent
        self.resetText = String(parts[1])
        self.status = String(parts[2])
    }
}
