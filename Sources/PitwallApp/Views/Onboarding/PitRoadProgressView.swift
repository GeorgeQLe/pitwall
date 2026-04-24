import PitwallAppSupport
import PitwallCore
import SwiftUI

struct PitRoadProgressView: View {
    let currentStep: OnboardingWizardStep
    let completedSteps: Set<OnboardingWizardStep>
    let selectedProviders: Set<ProviderID>

    private let mainY: CGFloat = 12
    private let pitY: CGFloat = 42

    private var positions: [OnboardingTrackPosition] {
        OnboardingWizardStepSequencer.trackPositions(for: selectedProviders)
    }

    private var steps: [OnboardingWizardStep] {
        OnboardingWizardStepSequencer.steps(for: selectedProviders)
    }

    private var pitProviders: [ProviderID] {
        OnboardingWizardStepSequencer.pitProviders(for: selectedProviders)
    }

    private var hasPitRoad: Bool { !pitProviders.isEmpty }

    private func stepIndex(of step: OnboardingWizardStep) -> Int? {
        steps.firstIndex(of: step)
    }

    private func currentStepIndex() -> Int {
        stepIndex(of: currentStep) ?? 0
    }

    private enum NodeState {
        case completed, current, upcoming
    }

    private func nodeState(for step: OnboardingWizardStep) -> NodeState {
        if completedSteps.contains(step) { return .completed }
        if step == currentStep { return .current }
        return .upcoming
    }

    private func lineColor(afterStepIndex idx: Int) -> Color {
        idx < currentStepIndex() ? Color.accentColor : Color(nsColor: .separatorColor)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let mainXs = mainNodeXPositions(width: w)
            let pitXs = pitNodeXPositions(mainXs: mainXs)

            ZStack(alignment: .topLeading) {
                mainRoadLines(mainXs: mainXs, pitXs: pitXs)
                pitRoadLines(mainXs: mainXs, pitXs: pitXs)
                mainNodes(mainXs: mainXs)
                pitNodes(pitXs: pitXs)
            }
        }
        .frame(height: hasPitRoad ? 60 : 24)
        .animation(.easeInOut(duration: 0.3), value: selectedProviders)
    }

    // MARK: - Layout

    private func mainNodeXPositions(width: CGFloat) -> [CGFloat] {
        let count = 4
        let inset: CGFloat = 10
        let usable = width - inset * 2
        return (0..<count).map { i in inset + usable * CGFloat(i) / CGFloat(count - 1) }
    }

    private func pitNodeXPositions(mainXs: [CGFloat]) -> [CGFloat] {
        let count = pitProviders.count
        guard count > 0 else { return [] }
        let left = mainXs[1]
        let right = mainXs[2]
        let padding: CGFloat = 30
        let span = right - left - padding * 2
        if count == 1 {
            return [(left + right) / 2]
        }
        return (0..<count).map { i in
            left + padding + span * CGFloat(i) / CGFloat(count - 1)
        }
    }

    // MARK: - Main Road Lines

    private func mainRoadLines(mainXs: [CGFloat], pitXs: [CGFloat]) -> some View {
        let toolsMainIdx = stepIndex(of: .toolSelection) ?? 1
        let prefsMainIdx = stepIndex(of: .preferences) ?? (steps.count - 2)

        return ForEach(0..<3, id: \.self) { seg in
            let fromX = mainXs[seg]
            let toX = mainXs[seg + 1]

            if seg == 1 && hasPitRoad {
                EmptyView()
            } else {
                let segStepIdx: Int = seg == 0 ? 0 : (seg == 1 ? toolsMainIdx : prefsMainIdx)
                Path { p in
                    p.move(to: CGPoint(x: fromX, y: mainY))
                    p.addLine(to: CGPoint(x: toX, y: mainY))
                }
                .stroke(lineColor(afterStepIndex: segStepIdx), lineWidth: 2)
            }
        }
    }

    // MARK: - Pit Road Lines

    @ViewBuilder
    private func pitRoadLines(mainXs: [CGFloat], pitXs: [CGFloat]) -> some View {
        if hasPitRoad {
            let toolsX = mainXs[1]
            let prefsX = mainXs[2]
            let firstPitX = pitXs[0]
            let lastPitX = pitXs[pitXs.count - 1]
            let toolsStepIdx = currentStepIndex()
            let toolsMainIdx = stepIndex(of: .toolSelection) ?? 1

            Path { p in
                p.move(to: CGPoint(x: toolsX, y: mainY))
                p.addLine(to: CGPoint(x: firstPitX, y: pitY))
            }
            .stroke(lineColor(afterStepIndex: toolsMainIdx), lineWidth: 2)

            ForEach(0..<max(pitXs.count - 1, 0), id: \.self) { i in
                let fromX = pitXs[i]
                let toX = pitXs[i + 1]
                let pitStepIdx = stepIndex(of: .credentials(pitProviders[i])) ?? toolsStepIdx
                Path { p in
                    p.move(to: CGPoint(x: fromX, y: pitY))
                    p.addLine(to: CGPoint(x: toX, y: pitY))
                }
                .stroke(lineColor(afterStepIndex: pitStepIdx), lineWidth: 2)
            }

            let lastPitStep = stepIndex(of: .credentials(pitProviders.last!)) ?? toolsStepIdx
            Path { p in
                p.move(to: CGPoint(x: lastPitX, y: pitY))
                p.addLine(to: CGPoint(x: prefsX, y: mainY))
            }
            .stroke(lineColor(afterStepIndex: lastPitStep), lineWidth: 2)
        }
    }

    // MARK: - Nodes

    private func mainNodes(mainXs: [CGFloat]) -> some View {
        let mainSteps: [OnboardingWizardStep] = [.welcome, .toolSelection, .preferences, .summary]
        let labels = ["Welcome", "Tools", "Prefs", "Summary"]
        return ForEach(0..<4, id: \.self) { i in
            nodeView(step: mainSteps[i], label: labels[i], x: mainXs[i], y: mainY)
        }
    }

    @ViewBuilder
    private func pitNodes(pitXs: [CGFloat]) -> some View {
        if hasPitRoad {
            ForEach(0..<pitProviders.count, id: \.self) { i in
                let provider = pitProviders[i]
                let label = providerAbbreviation(provider)
                nodeView(step: .credentials(provider), label: label, x: pitXs[i], y: pitY)
                    .transition(.opacity)
            }
        }
    }

    private func nodeView(step: OnboardingWizardStep, label: String, x: CGFloat, y: CGFloat) -> some View {
        let state = nodeState(for: step)
        let radius: CGFloat = 8
        let borderColor = state == .upcoming ? Color(nsColor: .separatorColor) : Color.accentColor
        return ZStack {
            Circle()
                .fill(state == .upcoming ? Color.clear : Color.accentColor)
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle().strokeBorder(borderColor, lineWidth: 2)
                )

            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .top) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .offset(y: radius * 2 + 2)
                .fixedSize()
        }
        .position(x: x, y: y)
    }

    private func providerAbbreviation(_ id: ProviderID) -> String {
        switch id {
        case .claude: return "C"
        case .codex: return "X"
        case .gemini: return "G"
        default: return String(id.rawValue.prefix(1)).uppercased()
        }
    }
}
