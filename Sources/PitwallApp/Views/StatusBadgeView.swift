import SwiftUI

struct StatusBadgeView: View {
    enum Style {
        case neutral
        case success
        case warning
        case critical
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}
