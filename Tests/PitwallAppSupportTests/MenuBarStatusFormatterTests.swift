import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class MenuBarStatusFormatterTests: XCTestCase {
    func testFormatsConfiguredProviderWithExactMetricCountdownAndAction() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 42.4,
                weeklyPace: PaceEvaluation(label: .warning, action: .conserve)
            )
        )

        let text = MenuBarStatusFormatter().format(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown),
            now: now
        )

        XCTAssertEqual(text, "Claude - 42.4% - 2h 30m - conserve")
    }

    func testFormatsMissingConfigurationAsConfigureWithoutFakePrecision() {
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: "Claude credentials missing"
        )

        let text = MenuBarStatusFormatter().format(provider: provider)

        XCTAssertEqual(text, "Claude configure")
        XCTAssertFalse(text.contains("%"))
    }

    func testResetTimePreferenceUsesAbsoluteResetText() {
        let resetAt = Date(timeIntervalSince1970: 1_700_000_000)

        let text = MenuBarStatusFormatter.resetText(
            resetWindow: ResetWindow(resetsAt: resetAt),
            preference: .resetTime,
            now: resetAt.addingTimeInterval(-60)
        )

        XCTAssertEqual(text?.hasPrefix("resets "), true)
        XCTAssertNotEqual(text, "1m")
    }

    func testFormatsSelectedProviderFromAppState() {
        let appState = AppProviderState(
            providers: [
                provider(id: .claude, displayName: "Claude", primaryValue: "exact"),
                provider(id: .codex, displayName: "Codex", primaryValue: "observed")
            ],
            selectedProviderId: .codex
        )

        let text = MenuBarStatusFormatter().format(appState: appState)

        XCTAssertTrue(text.hasPrefix("Codex - observed"))
    }

    func testAppStateFormattingSkipsUnconfiguredSelectedProvider() {
        let appState = AppProviderState(
            providers: [
                ProviderState(
                    providerId: .claude,
                    displayName: "Claude",
                    status: .missingConfiguration,
                    confidence: .observedOnly,
                    headline: "Claude credentials missing"
                ),
                provider(id: .codex, displayName: "Codex", primaryValue: "observed")
            ],
            selectedProviderId: .claude
        )

        let formatter = MenuBarStatusFormatter()

        XCTAssertTrue(formatter.format(appState: appState).hasPrefix("Codex - observed"))
        XCTAssertTrue(formatter.menuBarTitle(appState: appState).hasPrefix("Codex observed"))
    }

    func testMenuBarTitleUsesClaudeRichBreakdownWhenAvailable() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 42.4,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 57.6,
                    daysRemaining: 2.5,
                    dailyBudgetPercent: 18,
                    todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12)
                ),
                todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12),
                weeklyPace: PaceEvaluation(label: .warning, action: .conserve)
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "usageRows",
                    values: ["Session": "26|2h 30m|exact"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running),
            now: now
        )

        XCTAssertEqual(text, "Claude 🚶 26% 🎯 12%/18%/day 🚶 42.4%/w 2h 30m")
    }

    func testMenuBarTitleFallsBackToGenericSummaryForNonClaudeProviders() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .exact,
            headline: "Codex ready",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 42.4,
                weeklyPace: PaceEvaluation(label: .warning, action: .conserve)
            )
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown),
            now: now
        )

        XCTAssertEqual(text, "Codex 42.4% 2h 30m conserve")
    }

    func testMenuBarTitleUsesSelectedClaudeTheme() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 80,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 20,
                    daysRemaining: 1,
                    dailyBudgetPercent: 20,
                    todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 40)
                ),
                todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 40),
                weeklyPace: PaceEvaluation(
                    label: .critical,
                    action: .conserve,
                    expectedUtilizationPercent: 50
                ),
                sessionPace: PaceEvaluation(
                    label: .critical,
                    action: .conserve,
                    expectedUtilizationPercent: 20
                )
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "usageRows",
                    values: ["Session": "70|2h 30m|exact"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .racecar),
            now: now
        )

        XCTAssertEqual(text, "Claude 🚨 70% 🏁 40%/20%/day 🚨 80%/w 2h 30m")
    }

    func testMenuBarTitleFallsBackToConfigureWhenNothingSelected() {
        let text = MenuBarStatusFormatter().menuBarTitle(appState: AppProviderState())

        XCTAssertEqual(text, "Configure")
    }

    private func provider(
        id: ProviderID,
        displayName: String,
        primaryValue: String
    ) -> ProviderState {
        ProviderState(
            providerId: id,
            displayName: displayName,
            status: .configured,
            confidence: .estimated,
            headline: "\(displayName) ready",
            primaryValue: primaryValue
        )
    }
}
