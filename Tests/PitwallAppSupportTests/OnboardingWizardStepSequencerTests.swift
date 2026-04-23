import XCTest
@testable import PitwallAppSupport
import PitwallCore

final class OnboardingWizardStepSequencerTests: XCTestCase {
    func testNoProvidersSelectedProducesBaseSteps() {
        let steps = OnboardingWizardStepSequencer.steps(for: [])
        XCTAssertEqual(steps, [.welcome, .toolSelection, .preferences, .summary])
    }

    func testClaudeOnlyInsertsSingleCredentialStep() {
        let steps = OnboardingWizardStepSequencer.steps(for: [.claude])
        XCTAssertEqual(
            steps,
            [.welcome, .toolSelection, .credentials(.claude), .preferences, .summary]
        )
    }

    func testAllThreeProvidersKeepCanonicalOrder() {
        let steps = OnboardingWizardStepSequencer.steps(for: [.gemini, .codex, .claude])
        XCTAssertEqual(
            steps,
            [
                .welcome,
                .toolSelection,
                .credentials(.claude),
                .credentials(.codex),
                .credentials(.gemini),
                .preferences,
                .summary
            ]
        )
    }

    func testTogglingProviderChangesStepList() {
        let initial = OnboardingWizardStepSequencer.steps(for: [.claude])
        let updated = OnboardingWizardStepSequencer.steps(for: [.claude, .codex])
        XCTAssertEqual(initial.count, 5)
        XCTAssertEqual(updated.count, 6)
        XCTAssertTrue(updated.contains(.credentials(.codex)))
    }

    func testStepsAreDeterministicAcrossCalls() {
        let first = OnboardingWizardStepSequencer.steps(for: [.codex, .gemini])
        let second = OnboardingWizardStepSequencer.steps(for: [.codex, .gemini])
        XCTAssertEqual(first, second)
    }
}
