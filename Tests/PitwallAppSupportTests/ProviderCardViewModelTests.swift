import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderCardViewModelTests: XCTestCase {
    func testConfiguredClaudeCardShowsMetricsConfidenceResetAndAction() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(90 * 60)),
            lastUpdatedAt: now.addingTimeInterval(-5 * 60),
            pacingState: PacingState(
                weeklyUtilizationPercent: 31.2,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 68.8,
                    daysRemaining: 2.5,
                    dailyBudgetPercent: 27.52,
                    todayUsage: TodayUsage(status: .unknown)
                ),
                weeklyPace: PaceEvaluation(label: .underusing, action: .push)
            ),
            confidenceExplanation: "Claude returned fresh usage data."
        )

        let viewModel = ProviderCardViewModel(provider: provider, now: now)

        XCTAssertEqual(viewModel.displayName, "Claude")
        XCTAssertEqual(viewModel.statusText, "Configured")
        XCTAssertEqual(viewModel.confidenceText, "Exact")
        XCTAssertEqual(viewModel.primaryMetric, "31.2% used")
        XCTAssertEqual(viewModel.secondaryMetric, "27.5%/day for 2.5d")
        XCTAssertEqual(viewModel.resetText, "1h 30m")
        XCTAssertEqual(viewModel.lastUpdatedText, "Updated 5m ago")
        XCTAssertEqual(viewModel.recommendedActionText, "push")
        XCTAssertEqual(viewModel.badges, [])
    }

    func testMissingProviderCardRemainsVisibleAndConfigurable() {
        let provider = ProviderState(
            providerId: .gemini,
            displayName: "Gemini",
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: "Gemini configuration missing",
            confidenceExplanation: "Gemini settings were not found.",
            actions: [
                ProviderAction(kind: .configure, title: "Configure Gemini")
            ]
        )

        let viewModel = ProviderCardViewModel(provider: provider)

        XCTAssertEqual(viewModel.providerId, .gemini)
        XCTAssertEqual(viewModel.statusText, "Missing setup")
        XCTAssertEqual(viewModel.confidenceText, "Observed only")
        XCTAssertEqual(viewModel.recommendedActionText, "configure")
        XCTAssertEqual(viewModel.badges, ["Missing setup"])
        XCTAssertEqual(viewModel.actions.map(\.kind), [.configure])
        XCTAssertNil(viewModel.primaryMetric)
    }

    func testDegradedProviderUsesHonestConfidenceAndBadge() {
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .degraded,
            confidence: .observedOnly,
            headline: "Codex local scan unavailable",
            confidenceExplanation: "Codex passive metadata could not be scanned."
        )

        let viewModel = ProviderCardViewModel(provider: provider)

        XCTAssertEqual(viewModel.confidenceText, "Observed only")
        XCTAssertEqual(viewModel.recommendedActionText, "configure")
        XCTAssertEqual(viewModel.badges, ["Degraded"])
        XCTAssertFalse(viewModel.confidenceExplanation.contains("exact"))
    }
}
