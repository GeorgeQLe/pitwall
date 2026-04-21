import XCTest
@testable import PitwallCore

final class ProviderDetectionTests: XCTestCase {
    func testCodexPassiveDetectionReportsSafeSignalsOnly() throws {
        let snapshot = LocalProviderFileSnapshot(
            homePath: "/Users/example/.codex",
            files: [
                "config.toml": "model = \"gpt-5.4\"\nprofile = \"work\"\n",
                "auth.json": "{\"access_token\":\"codex-secret-token\",\"refresh_token\":\"refresh-secret\"}",
                "history.jsonl": "{\"ts\":\"2026-02-08T18:00:00Z\",\"text\":\"build the private trading bot\"}\n",
                "sessions/2026/02/08/rollout-1.jsonl": "{\"event\":\"assistant\",\"stdout\":\"private source output\",\"message\":\"prompt body\"}\n",
                "logs/codex.log": "usage-limit reached; reset at 2026-02-08T21:00:00Z"
            ]
        )

        let state = try CodexLocalDetector().detect(from: snapshot)

        XCTAssertEqual(state.providerId, .codex)
        XCTAssertEqual(state.status, .configured)
        XCTAssertEqual(state.confidence, .estimated)
        XCTAssertEqual(state.payloads.first?.values["installDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["authDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["activityDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["rateLimitDetected"], "true")
        assertNoSensitiveValues(in: state, forbiddenFragments: [
            "codex-secret-token",
            "refresh-secret",
            "build the private trading bot",
            "private source output",
            "prompt body"
        ])
    }

    func testCodexPassiveDetectionHandlesMissingConfiguration() throws {
        let state = try CodexLocalDetector().detect(from: LocalProviderFileSnapshot(
            homePath: "/Users/example/.codex",
            files: [:]
        ))

        XCTAssertEqual(state.providerId, .codex)
        XCTAssertEqual(state.status, .missingConfiguration)
        XCTAssertEqual(state.confidence, .observedOnly)
        XCTAssertTrue(state.actions.contains { $0.kind == .configure })
    }

    func testGeminiPassiveDetectionReportsSafeSignalsOnly() throws {
        let snapshot = LocalProviderFileSnapshot(
            homePath: "/Users/example/.gemini",
            files: [
                "settings.json": "{\"selectedAuthType\":\"oauth-personal\",\"profile\":\"work\"}",
                "oauth_creds.json": "{\"access_token\":\"gemini-secret-token\",\"refresh_token\":\"refresh-secret\"}",
                "tmp/project/chats/session-123.json": "{\"timestamp\":\"2026-02-08T18:00:00Z\",\"raw_chat\":\"ship my unreleased app\",\"tokenCount\":1234}"
            ]
        )

        let state = try GeminiLocalDetector().detect(from: snapshot)

        XCTAssertEqual(state.providerId, .gemini)
        XCTAssertEqual(state.status, .configured)
        XCTAssertEqual(state.confidence, .estimated)
        XCTAssertEqual(state.payloads.first?.values["installDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["authDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["activityDetected"], "true")
        XCTAssertEqual(state.payloads.first?.values["tokenCountObserved"], "1234")
        assertNoSensitiveValues(in: state, forbiddenFragments: [
            "gemini-secret-token",
            "refresh-secret",
            "ship my unreleased app",
            "raw_chat"
        ])
    }

    func testGeminiPassiveDetectionHandlesMissingConfiguration() throws {
        let state = try GeminiLocalDetector().detect(from: LocalProviderFileSnapshot(
            homePath: "/Users/example/.gemini",
            files: [:]
        ))

        XCTAssertEqual(state.providerId, .gemini)
        XCTAssertEqual(state.status, .missingConfiguration)
        XCTAssertEqual(state.confidence, .observedOnly)
        XCTAssertTrue(state.actions.contains { $0.kind == .configure })
    }

    private func assertNoSensitiveValues(
        in state: ProviderState,
        forbiddenFragments: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let serializedState = String(describing: state)

        for fragment in forbiddenFragments {
            XCTAssertFalse(
                serializedState.contains(fragment),
                "ProviderState leaked sensitive fragment: \(fragment)",
                file: file,
                line: line
            )
        }
    }
}
