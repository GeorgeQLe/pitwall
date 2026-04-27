import AppKit
import PitwallCore
import SwiftUI

struct ProviderBrandView: View {
    enum Style {
        case cardHeader
        case row
    }

    let providerId: ProviderID
    let displayName: String
    var style: Style = .cardHeader

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: style == .cardHeader ? 8 : 6) {
            logo
            if providerId == .claude, style == .row {
                Text(displayName)
                    .font(textFont)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        switch providerId {
        case .claude:
            if let image = claudeImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: style == .cardHeader ? 18 : 16)
                    .accessibilityLabel(Text(displayName))
            } else {
                fallbackBadge
            }
        default:
            fallbackBadge
        }
    }

    private var fallbackBadge: some View {
        Text(displayName)
            .font(textFont)
            .foregroundStyle(.primary)
            .padding(.horizontal, style == .cardHeader ? 8 : 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private var textFont: Font {
        .system(size: style == .cardHeader ? 15 : 13, weight: .semibold)
    }

    private var claudeImage: NSImage? {
        let resourceName = colorScheme == .dark ? "claude-logo-ivory" : "claude-logo-slate"
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png", subdirectory: "Resources/Brand") ??
            Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}
