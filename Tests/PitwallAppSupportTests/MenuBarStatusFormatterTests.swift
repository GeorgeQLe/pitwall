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

    func testMenuBarTitleSkipsConfiguredProviderWithoutDisplayableSignal() {
        let appState = AppProviderState(
            providers: [
                ProviderState(
                    providerId: .gemini,
                    displayName: "Gemini",
                    status: .configured,
                    confidence: .estimated,
                    headline: "Gemini local evidence detected"
                )
            ],
            selectedProviderId: .gemini
        )

        let formatter = MenuBarStatusFormatter()

        XCTAssertEqual(formatter.menuBarTitle(appState: appState), "Configure")
        XCTAssertEqual(formatter.format(appState: appState), "Pitwall configure")
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
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Claude 🚶 26% 🦥 12%/18%/day 🚶 42.4%/w 2h 30m 0s")
    }

    func testToolTipUsesClaudeRichBreakdownWhenAvailable() {
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
            confidenceExplanation: "Claude returned fresh usage data for the selected account.",
            payloads: [
                ProviderSpecificPayload(
                    source: "usageRows",
                    values: ["Session": "26|2h 30m|exact"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().toolTip(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown),
            now: now
        )

        XCTAssertEqual(
            text,
            """
            Claude
            Claude usage refreshed
            Session: 74% left
            Today: 88% left / 18% target
            Weekly: 42.4%
            Recommendation: conserve
            Reset: 2h 30m 0s
            Claude returned fresh usage data for the selected account.
            """
        )
    }

    func testMenuBarTitleUsesRichBreakdownForCodexProviderSuppliedQuota() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .providerSupplied,
            headline: "Codex ready",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 42.4,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 57.6,
                    daysRemaining: 2.5,
                    dailyBudgetPercent: 18,
                    todayUsage: TodayUsage(status: .estimatedFromSameDayBaseline, utilizationDeltaPercent: 12)
                ),
                todayUsage: TodayUsage(status: .estimatedFromSameDayBaseline, utilizationDeltaPercent: 12),
                weeklyPace: PaceEvaluation(
                    label: .warning,
                    action: .conserve,
                    expectedUtilizationPercent: 30
                ),
                sessionPace: PaceEvaluation(
                    label: .warning,
                    action: .conserve,
                    expectedUtilizationPercent: 20
                )
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "codex-rate-limits",
                    values: ["primary": "26|300|2023-11-14T23:43:20Z"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Codex 🏃 26% 🦥 12%/18%/day 🔥 42.4%/w 1h 30m 0s")
    }

    func testCodexMenuBarTitleUsesPrimaryFiveHourResetCountdown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .providerSupplied,
            headline: "Codex ready",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 26,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 74,
                    daysRemaining: 3,
                    dailyBudgetPercent: 24.7,
                    todayUsage: TodayUsage(status: .estimatedFromSameDayBaseline, utilizationDeltaPercent: 6)
                ),
                todayUsage: TodayUsage(status: .estimatedFromSameDayBaseline, utilizationDeltaPercent: 6),
                weeklyPace: PaceEvaluation(
                    label: .onPace,
                    action: .push,
                    expectedUtilizationPercent: 24
                ),
                sessionPace: PaceEvaluation(
                    label: .onPace,
                    action: .push,
                    expectedUtilizationPercent: 20
                )
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "codex-rate-limits",
                    values: ["primary": "24|300|2023-11-14T23:13:20.000Z"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Codex 🏃 24% 🛌 6%/24.7%/day 🚶 26%/w 1h 0m 0s")
    }

    func testCodexMenuBarTitleUsesFiveHourSessionUsedWithSharedUsageScheme() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .providerSupplied,
            headline: "Codex ready",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 8,
                weeklyPace: PaceEvaluation(
                    label: .behindPace,
                    action: .push,
                    expectedUtilizationPercent: 20
                ),
                sessionPace: PaceEvaluation(
                    label: .warning,
                    action: .conserve,
                    expectedUtilizationPercent: 50
                )
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "codex-rate-limits",
                    values: ["primary": "60|300|2023-11-14T23:13:20.000Z"]
                )
            ]
        )

        let formatter = MenuBarStatusFormatter()
        let title = formatter.menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running, menuBarTitleMode: .rich),
            now: now
        )
        let tooltip = formatter.toolTip(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .running),
            now: now
        )

        XCTAssertEqual(title, "Codex 🏃 60% 🛌 8%/w 1h 0m 0s")
        XCTAssertTrue(tooltip.contains("Session: 40% left"))
        XCTAssertTrue(tooltip.contains("Weekly: 8%"))
    }

    func testCompactMenuBarTitleUsesShortProviderMetricByDefault() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .gemini,
            displayName: "Gemini",
            status: .configured,
            confidence: .estimated,
            headline: "Gemini ready",
            primaryValue: "observed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(62))
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown),
            now: now
        )

        XCTAssertEqual(text, "Gemini observed")
    }

    func testCompactMenuBarTitleUsesProviderPrimaryMetricBeforeSessionRows() {
        let provider = ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .providerSupplied,
            headline: "Codex usage refreshed",
            primaryValue: "39% session left",
            pacingState: PacingState(weeklyUtilizationPercent: 44),
            payloads: [
                ProviderSpecificPayload(
                    source: "codex-rate-limits",
                    values: ["primary": "61|300|2023-11-14T23:13:20.000Z"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(provider: provider)

        XCTAssertEqual(text, "Codex 39% left")
    }

    func testCompactMenuBarTitleUsesClaudePrimaryMetricBeforeSessionRows() {
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            primaryValue: "44% used",
            pacingState: PacingState(weeklyUtilizationPercent: 44),
            payloads: [
                ProviderSpecificPayload(
                    source: "usageRows",
                    values: ["Session": "61|2026-04-29T17:00:00.000Z|exact"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(provider: provider)

        XCTAssertEqual(text, "Claude 39% left")
    }

    func testMenuBarTitleUsesThemeForCodexWeeklyQuotaWithoutSessionPayload() {
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
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Codex 🚶 42.4%/w 2h 30m 0s")
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
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .racecar, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Claude 🚨 70% 🚨 40%/20%/day 🚨 80%/w 2h 30m 0s")
    }

    func testF1ThemeUsesYellowForFarBehindDailyPace() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            pacingState: PacingState(
                weeklyUtilizationPercent: 30,
                dailyBudget: DailyBudget(
                    remainingUtilizationPercent: 70,
                    daysRemaining: 2,
                    dailyBudgetPercent: 40,
                    todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 10)
                ),
                todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 10),
                weeklyPace: PaceEvaluation(
                    label: .onPace,
                    action: .push,
                    expectedUtilizationPercent: 30
                ),
                sessionPace: PaceEvaluation(
                    label: .onPace,
                    action: .push,
                    expectedUtilizationPercent: 30
                )
            ),
            payloads: [
                ProviderSpecificPayload(
                    source: "usageRows",
                    values: ["Session": "10|2h 30m|exact"]
                )
            ]
        )

        let text = MenuBarStatusFormatter().menuBarTitle(
            provider: provider,
            preferences: UserPreferences(resetDisplayPreference: .countdown, menuBarTheme: .f1Quali, menuBarTitleMode: .rich),
            now: now
        )

        XCTAssertEqual(text, "Claude 🟡 10% 🟡 10%/40%/day 🟣 30%/w 2h 30m 0s")
    }

    func testMenuBarTitleFallsBackToConfigureWhenNothingSelected() {
        let text = MenuBarStatusFormatter().menuBarTitle(appState: AppProviderState())

        XCTAssertEqual(text, "Configure")
    }

    func testToolTipFallsBackToConfigureWhenNothingSelected() {
        let text = MenuBarStatusFormatter().toolTip(appState: AppProviderState())

        XCTAssertEqual(text, "Pitwall\nConfigure a provider to show live pacing.")
    }

    func testToolTipDescribesSelectedUntrackedProviderBeforeGenericConfigure() {
        let appState = AppProviderState(
            providers: [
                ProviderState(
                    providerId: .claude,
                    displayName: "Claude",
                    status: .missingConfiguration,
                    confidence: .observedOnly,
                    headline: "Claude credentials missing"
                )
            ],
            selectedProviderId: .claude
        )

        let text = MenuBarStatusFormatter().toolTip(appState: appState)

        XCTAssertEqual(text, "Claude\nConfigure credentials to show live usage.")
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
