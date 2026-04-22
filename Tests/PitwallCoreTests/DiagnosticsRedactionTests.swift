import XCTest
@testable import PitwallCore

final class DiagnosticsRedactionTests: XCTestCase {
    func testRedactsSecretsAndRawContentFromDiagnosticEvents() {
        let event = DiagnosticEvent(
            providerId: .claude,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            summary: "Claude refresh failed for acct_sensitive with github_pat_sensitive",
            details: [
                "cookie": "sessionKey=sk-ant-secret",
                "authorization": "Bearer ghp_secret",
                "accountId": "acct_sensitive",
                "rawResponse": #"{"prompt":"private prompt","completion":"private model response"}"#,
                "raw_response": #"{"prompt":"snake private prompt"}"#,
                "model_response": "snake private model response",
                "session_key": "snake private session key",
                "source_content": "snake private source content",
                "stdout": "private source output",
                "token": "tok_secret"
            ]
        )

        let redacted = DiagnosticsRedactor().redact(event)
        let serialized = String(describing: redacted)

        XCTAssertFalse(serialized.contains("sk-ant-secret"))
        XCTAssertFalse(serialized.contains("ghp_secret"))
        XCTAssertFalse(serialized.contains("github_pat_sensitive"))
        XCTAssertFalse(serialized.contains("acct_sensitive"))
        XCTAssertFalse(serialized.contains("private prompt"))
        XCTAssertFalse(serialized.contains("private model response"))
        XCTAssertFalse(serialized.contains("snake private prompt"))
        XCTAssertFalse(serialized.contains("snake private model response"))
        XCTAssertFalse(serialized.contains("snake private session key"))
        XCTAssertFalse(serialized.contains("snake private source content"))
        XCTAssertFalse(serialized.contains("private source output"))
        XCTAssertFalse(serialized.contains("tok_secret"))
        XCTAssertTrue(serialized.contains("[redacted]"))
    }

    func testDiagnosticsExportPreservesSafeOperationalMetadata() {
        let export = DiagnosticsExportBuilder(
            appVersion: "1.0",
            buildNumber: "42",
            enabledProviderIds: [.claude, .codex],
            providerStates: [
                ProviderState(
                    providerId: .claude,
                    displayName: "Claude",
                    status: .stale,
                    confidence: .exact,
                    headline: "Claude usage stale",
                    lastUpdatedAt: Date(timeIntervalSince1970: 1_799_999_000),
                    confidenceExplanation: "Last exact refresh is stale."
                )
            ],
            storageHealth: StorageHealth(status: .healthy, lastSuccessfulWriteAt: Date(timeIntervalSince1970: 1_799_998_000)),
            diagnosticEvents: [
                DiagnosticEvent(
                    providerId: .claude,
                    occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
                    summary: "Network unavailable",
                    details: ["error": "timeout after redacted request"]
                )
            ]
        ).build()

        let serialized = String(describing: export)

        XCTAssertTrue(serialized.contains("1.0"))
        XCTAssertTrue(serialized.contains("42"))
        XCTAssertTrue(serialized.contains("claude"))
        XCTAssertTrue(serialized.contains("codex"))
        XCTAssertTrue(serialized.contains("stale"))
        XCTAssertTrue(serialized.contains("exact"))
        XCTAssertTrue(serialized.contains("healthy"))
        XCTAssertTrue(serialized.contains("Network unavailable"))
    }
}
