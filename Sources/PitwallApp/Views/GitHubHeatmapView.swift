import PitwallAppSupport
import PitwallCore
import SwiftUI

struct GitHubHeatmapView: View {
    let heatmap: GitHubHeatmap?
    let settings: GitHubHeatmapSettings
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GitHub")
                        .font(.system(size: 13, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh GitHub heatmap")
                .disabled(settings.username.isEmpty || settings.tokenState != .configured)
            }

            if let heatmap, !heatmap.weeks.isEmpty {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(heatmap.weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color(for: day))
                                    .frame(width: 8, height: 8)
                                    .help("\(day.date): \(day.contributionCount) contributions")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        switch settings.tokenState {
        case .missing:
            return "Configure token in Settings"
        case .configured:
            if let lastRefreshAt = settings.lastRefreshAt {
                return "\(settings.username) updated \(lastRefreshAt.formatted(date: .abbreviated, time: .shortened))"
            }
            return settings.username.isEmpty ? "Username missing" : settings.username
        case .invalidOrExpired:
            return "Token invalid or expired"
        }
    }

    private var emptyText: String {
        if settings.username.isEmpty {
            return "Username missing"
        }

        if settings.tokenState != .configured {
            return statusText
        }

        return "No heatmap data yet"
    }

    private func color(for day: GitHubHeatmapDay) -> Color {
        Color(hex: day.color) ?? Color(nsColor: .separatorColor)
    }
}

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let value = Int(hex, radix: 16)
        else {
            return nil
        }

        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
