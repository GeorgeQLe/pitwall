import XCTest
@testable import PitwallCore

final class ProviderConfidenceTests: XCTestCase {
    func testMapsClaudeExactUsageToExactConfidence() {
        let result = ProviderConfidenceMapper().map(.claudeUsage(
            refreshedAt: Date(timeIntervalSince1970: 1_800_000_000),
            hasCurrentUsage: true
        ))

        XCTAssertEqual(result.label, .exact)
        XCTAssertEqual(result.providerStatus, .configured)
        XCTAssertTrue(result.explanation.contains("fresh Claude usage"))
    }

    func testMapsCodexPassiveStates() {
        let mapper = ProviderConfidenceMapper()

        XCTAssertEqual(mapper.map(.codexPassive(
            installDetected: true,
            authDetected: true,
            activityDetected: true,
            configuredPlan: "Plus",
            repeatedLimitSignals: true
        )).label, .highConfidence)

        XCTAssertEqual(mapper.map(.codexPassive(
            installDetected: true,
            authDetected: true,
            activityDetected: true,
            configuredPlan: "Plus",
            repeatedLimitSignals: false
        )).label, .estimated)

        XCTAssertEqual(mapper.map(.codexPassive(
            installDetected: true,
            authDetected: true,
            activityDetected: true,
            configuredPlan: nil,
            repeatedLimitSignals: false
        )).label, .observedOnly)
    }

    func testMapsGeminiPassiveStates() {
        let mapper = ProviderConfidenceMapper()

        XCTAssertEqual(mapper.map(.geminiPassive(
            installDetected: true,
            authDetected: true,
            activityDetected: true,
            configuredProfile: "work",
            commandSummaryAvailable: true
        )).label, .highConfidence)

        XCTAssertEqual(mapper.map(.geminiPassive(
            installDetected: true,
            authDetected: true,
            activityDetected: true,
            configuredProfile: "work",
            commandSummaryAvailable: false
        )).label, .estimated)

        XCTAssertEqual(mapper.map(.geminiPassive(
            installDetected: true,
            authDetected: false,
            activityDetected: true,
            configuredProfile: nil,
            commandSummaryAvailable: false
        )).label, .observedOnly)
    }

    func testMapsDegradedTelemetryToEstimatedFallback() {
        let result = ProviderConfidenceMapper().map(.telemetryDegraded(
            providerId: .codex,
            fallbackActivityDetected: true,
            reason: "shape changed"
        ))

        XCTAssertEqual(result.label, .estimated)
        XCTAssertEqual(result.providerStatus, .degraded)
        XCTAssertTrue(result.explanation.contains("shape changed"))
    }

    func testMapsMissingConfigurationToObservedOnlyConfigureState() {
        let result = ProviderConfidenceMapper().map(.missingConfiguration(providerId: .gemini))

        XCTAssertEqual(result.label, .observedOnly)
        XCTAssertEqual(result.providerStatus, .missingConfiguration)
        XCTAssertTrue(result.explanation.contains("configuration"))
    }
}
