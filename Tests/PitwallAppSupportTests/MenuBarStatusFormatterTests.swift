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
