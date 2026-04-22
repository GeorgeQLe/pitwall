import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallWindows

final class WindowsTrayMenuTests: XCTestCase {
    private func makeProvider(
        id: ProviderID,
        status: ProviderStatus = .configured,
        confidence: ConfidenceLabel = .highConfidence,
        weekly: Double? = 42.0,
        resetsAt: Date? = nil
    ) -> ProviderState {
        ProviderState(
            providerId: id,
            displayName: id.rawValue.capitalized,
            status: status,
            confidence: confidence,
            headline: "\(id.rawValue) ok",
            primaryValue: nil,
            secondaryValue: nil,
            resetWindow: resetsAt.map { ResetWindow(resetsAt: $0) },
            lastUpdatedAt: nil,
            pacingState: weekly.map { PacingState(weeklyUtilizationPercent: $0) },
            confidenceExplanation: "",
            actions: [],
            payloads: []
        )
    }

    func test_build_producesCardsPerProviderWithSelectionFlag() {
        let now = Date(timeIntervalSince1970: 10_000)
        let providers = [
            makeProvider(id: .claude, weekly: 42.0, resetsAt: now.addingTimeInterval(3600)),
            makeProvider(id: .codex, weekly: 10.0)
        ]

        let builder = WindowsTrayMenuBuilder()
        let vm = builder.build(
            providers: providers,
            selectedProviderId: .claude,
            preferences: UserPreferences(),
            now: now
        )

        XCTAssertEqual(vm.providerCards.count, 2)
        XCTAssertTrue(vm.providerCards[0].isSelected)
        XCTAssertFalse(vm.providerCards[1].isSelected)
        XCTAssertEqual(vm.providerCards[0].metric, "42%")
        XCTAssertTrue(vm.tooltip.contains("Claude"))
    }

    func test_build_withNoSelection_fallsBackToFirstProviderTooltip() {
        let builder = WindowsTrayMenuBuilder()
        let vm = builder.build(
            providers: [makeProvider(id: .claude)],
            selectedProviderId: nil,
            preferences: UserPreferences(),
            now: Date()
        )

        XCTAssertTrue(vm.tooltip.contains("Claude"))
    }

    func test_build_emptyProviders_returnsConfigureTooltip() {
        let builder = WindowsTrayMenuBuilder()
        let vm = builder.build(
            providers: [],
            selectedProviderId: nil,
            preferences: UserPreferences(),
            now: Date()
        )

        XCTAssertEqual(vm.tooltip, "Pitwall — configure")
        XCTAssertTrue(vm.providerCards.isEmpty)
    }

    func test_build_missingConfigurationProvider_reportsConfigureTooltip() {
        let builder = WindowsTrayMenuBuilder()
        let provider = makeProvider(id: .claude, status: .missingConfiguration, weekly: nil)
        let vm = builder.build(
            providers: [provider],
            selectedProviderId: .claude,
            preferences: UserPreferences(),
            now: Date()
        )

        XCTAssertEqual(vm.tooltip, "Claude — configure")
    }
}
