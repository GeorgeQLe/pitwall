import PitwallCore
import SwiftUI

struct HistorySparklineView: View {
    let snapshots: [ProviderHistorySnapshot]

    private var values: [Double] {
        snapshots.compactMap { snapshot in
            snapshot.weeklyUtilizationPercent ?? snapshot.sessionUtilizationPercent
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if values.count > 1 {
                Path { path in
                    let points = sparklinePoints(in: proxy.size)
                    guard let first = points.first else {
                        return
                    }

                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private func sparklinePoints(in size: CGSize) -> [CGPoint] {
        let boundedValues = values.map { min(100, max(0, $0)) }
        guard let minValue = boundedValues.min(),
              let maxValue = boundedValues.max()
        else {
            return []
        }

        let range = max(maxValue - minValue, 1)
        let denominator = max(boundedValues.count - 1, 1)
        return boundedValues.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(denominator)
            let normalized = (value - minValue) / range
            let y = size.height - (size.height * CGFloat(normalized))
            return CGPoint(x: x, y: y)
        }
    }

    private var accessibilityText: String {
        guard let latest = values.last else {
            return "No provider history"
        }

        return "Provider history latest utilization \(Int(latest.rounded())) percent"
    }
}
