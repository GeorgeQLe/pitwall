import PitwallAppSupport
import PitwallCore
import SwiftUI

struct ProviderCardView: View {
    let viewModel: ProviderCardViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let actionHandler: (ProviderAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            metrics

            Text(viewModel.confidenceExplanation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actions
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(viewModel.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    StatusBadgeView(text: viewModel.statusText, style: badgeStyle)
                }

                Text(viewModel.headline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.primaryMetric ?? viewModel.confidenceText)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(viewModel.lastUpdatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            smallMetric("Action", viewModel.recommendedActionText.capitalized)
            smallMetric("Reset", viewModel.resetText ?? "Unknown")
            smallMetric("Signal", viewModel.confidenceText)
        }
    }

    private func smallMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { _, action in
                Button(action.title) {
                    actionHandler(action)
                }
                .disabled(!action.isEnabled)
                .controlSize(.small)
            }

            Spacer()

            ForEach(viewModel.badges, id: \.self) { badge in
                StatusBadgeView(text: badge, style: .warning)
            }
        }
        .buttonStyle(.bordered)
    }

    private var cardBackground: Color {
        isSelected
            ? Color.accentColor.opacity(0.08)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var badgeStyle: StatusBadgeView.Style {
        switch viewModel.statusText {
        case "Configured":
            return .success
        case "Missing setup", "Expired":
            return .warning
        case "Stale", "Degraded":
            return .critical
        default:
            return .neutral
        }
    }
}
