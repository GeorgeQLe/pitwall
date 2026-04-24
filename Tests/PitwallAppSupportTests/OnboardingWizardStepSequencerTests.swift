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

    // MARK: - Track Positions

    func testTrackPositionsNoProvidersHasNopit() {
        let positions = OnboardingWizardStepSequencer.trackPositions(for: [])
        XCTAssertEqual(positions.count, 4)
        XCTAssertEqual(positions[0].lane, .main(index: 0))
        XCTAssertEqual(positions[0].step, .welcome)
        XCTAssertEqual(positions[1].lane, .main(index: 1))
        XCTAssertEqual(positions[1].step, .toolSelection)
        XCTAssertEqual(positions[2].lane, .main(index: 2))
        XCTAssertEqual(positions[2].step, .preferences)
        XCTAssertEqual(positions[3].lane, .main(index: 3))
        XCTAssertEqual(positions[3].step, .summary)
    }

    func testTrackPositionsAllProvidersAssignPitLanes() {
        let positions = OnboardingWizardStepSequencer.trackPositions(for: [.claude, .codex, .gemini])
        let pitPositions = positions.filter {
            if case .pit = $0.lane { return true }
            return false
        }
        XCTAssertEqual(pitPositions.count, 3)
        XCTAssertEqual(pitPositions[0].lane, .pit(index: 0))
        XCTAssertEqual(pitPositions[0].step, .credentials(.claude))
        XCTAssertEqual(pitPositions[1].lane, .pit(index: 1))
        XCTAssertEqual(pitPositions[1].step, .credentials(.codex))
        XCTAssertEqual(pitPositions[2].lane, .pit(index: 2))
        XCTAssertEqual(pitPositions[2].step, .credentials(.gemini))
    }

    func testTrackPositionsMainNodesAlwaysPresent() {
        let positions = OnboardingWizardStepSequencer.trackPositions(for: [.claude])
        let mainPositions = positions.filter {
            if case .main = $0.lane { return true }
            return false
        }
        XCTAssertEqual(mainPositions.count, 4)
        XCTAssertEqual(mainPositions.map(\.step), [.welcome, .toolSelection, .preferences, .summary])
    }

    func testPitProvidersFollowCanonicalOrder() {
        let pits = OnboardingWizardStepSequencer.pitProviders(for: [.gemini, .claude])
        XCTAssertEqual(pits, [.claude, .gemini])
    }

    func testPitProvidersEmptyWhenNoneSelected() {
        let pits = OnboardingWizardStepSequencer.pitProviders(for: [])
        XCTAssertTrue(pits.isEmpty)
    }
}
