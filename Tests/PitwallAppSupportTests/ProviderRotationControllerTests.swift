import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class ProviderRotationControllerTests: XCTestCase {
    func testPinnedProviderWinsWhenCandidateIsHealthy() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .configured),
                provider(.codex, status: .configured)
            ],
            selectedProviderId: .claude,
            lastRotationAt: now
        )
        let preferences = UserPreferences(
            providerRotationMode: .pinned,
            pinnedProviderId: .codex
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            preferences: preferences,
            now: now.addingTimeInterval(20)
        )

        XCTAssertEqual(decision.selectedProviderId, .codex)
        XCTAssertEqual(decision.lastRotationAt, now)
        XCTAssertEqual(decision.reason, .pinned)
    }

    func testManualOverrideWinsBeforeAutomaticRotation() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .configured),
                provider(.codex, status: .configured),
                provider(.gemini, status: .configured)
            ],
            selectedProviderId: .claude,
            manualOverrideProviderId: .gemini,
            lastRotationAt: now.addingTimeInterval(-20)
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            now: now
        )

        XCTAssertEqual(decision.selectedProviderId, .gemini)
        XCTAssertEqual(decision.reason, .manualOverride)
    }

    func testAutomaticRotationWaitsForIntervalThenAdvances() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .configured),
                provider(.codex, status: .configured)
            ],
            selectedProviderId: .claude,
            lastRotationAt: now
        )
        let preferences = UserPreferences(rotationInterval: 7)

        let tooSoon = ProviderRotationController().nextSelection(
            appState: appState,
            preferences: preferences,
            now: now.addingTimeInterval(6)
        )
        let afterInterval = ProviderRotationController().nextSelection(
            appState: appState,
            preferences: preferences,
            now: now.addingTimeInterval(8)
        )

        XCTAssertEqual(tooSoon.selectedProviderId, .claude)
        XCTAssertEqual(tooSoon.reason, .intervalNotElapsed)
        XCTAssertEqual(afterInterval.selectedProviderId, .codex)
        XCTAssertEqual(afterInterval.reason, .rotated)
    }

    func testOnlyConfiguredProvidersParticipateInRotation() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .missingConfiguration),
                provider(.codex, status: .configured),
                provider(.gemini, status: .expired)
            ],
            selectedProviderId: .codex,
            lastRotationAt: now.addingTimeInterval(-20)
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            now: now
        )

        XCTAssertEqual(decision.selectedProviderId, .codex)
        XCTAssertEqual(decision.reason, .rotated)
    }

    func testNoRotationCandidatesWhenNothingIsConfigured() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .missingConfiguration),
                provider(.codex, status: .expired)
            ],
            selectedProviderId: .claude,
            lastRotationAt: now
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            now: now.addingTimeInterval(20)
        )

        XCTAssertNil(decision.selectedProviderId)
        XCTAssertEqual(decision.lastRotationAt, now)
        XCTAssertEqual(decision.reason, .noProviders)
    }

    func testFallsBackToFirstCandidateWhenSelectedProviderCannotRotate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .missingConfiguration),
                provider(.codex, status: .configured)
            ],
            selectedProviderId: .claude,
            lastRotationAt: now
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            now: now
        )

        XCTAssertEqual(decision.selectedProviderId, .codex)
        XCTAssertEqual(decision.lastRotationAt, now)
        XCTAssertEqual(decision.reason, .selectedFallback)
    }

    func testPausedRotationKeepsCurrentHealthySelection() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let appState = AppProviderState(
            providers: [
                provider(.claude, status: .configured),
                provider(.codex, status: .configured)
            ],
            selectedProviderId: .claude,
            rotationPaused: true,
            lastRotationAt: now.addingTimeInterval(-60)
        )

        let decision = ProviderRotationController().nextSelection(
            appState: appState,
            now: now
        )

        XCTAssertEqual(decision.selectedProviderId, .claude)
        XCTAssertEqual(decision.reason, .paused)
    }

    private func provider(_ id: ProviderID, status: ProviderStatus) -> ProviderState {
        ProviderState(
            providerId: id,
            displayName: id.rawValue.capitalized,
            status: status,
            confidence: status == .configured ? .estimated : .observedOnly,
            headline: "\(id.rawValue) state"
        )
    }
}
