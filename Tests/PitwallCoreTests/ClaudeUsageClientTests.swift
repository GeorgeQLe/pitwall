import XCTest
@testable import PitwallCore
import Foundation

final class ClaudeUsageClientTests: XCTestCase {
    func testResetWindowPrefersSessionOverWeekly() async throws {
        let sessionResetAt = ISO8601DateFormatter().date(from: "2026-02-08T18:59:59Z")!
        let weeklyResetAt = ISO8601DateFormatter().date(from: "2026-02-14T16:59:59Z")!

        let json: [String: Any] = [
            "five_hour": ["utilization": 17.0, "resets_at": "2026-02-08T18:59:59Z"],
            "seven_day": ["utilization": 11.0, "resets_at": "2026-02-14T16:59:59Z"]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let transport = StubTransport(response: ClaudeUsageHTTPResponse(
            statusCode: 200,
            headers: [:],
            data: data
        ))

        let client = ClaudeUsageClient(transport: transport)
        let account = ClaudeAccountMetadata(
            id: "acct_test",
            label: "Test",
            organizationId: "org_test"
        )

        let result = try await client.fetchUsage(
            account: account,
            sessionKey: "sk-test",
            now: ISO8601DateFormatter().date(from: "2026-02-08T14:00:00Z")!
        )

        XCTAssertEqual(result.providerState.resetWindow?.resetsAt, sessionResetAt)
        XCTAssertNotEqual(result.providerState.resetWindow?.resetsAt, weeklyResetAt)
    }

    func testResetWindowFallsBackToWeeklyWhenSessionMissing() async throws {
        let weeklyResetAt = ISO8601DateFormatter().date(from: "2026-02-14T16:59:59Z")!

        let json: [String: Any] = [
            "seven_day": ["utilization": 11.0, "resets_at": "2026-02-14T16:59:59Z"]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let transport = StubTransport(response: ClaudeUsageHTTPResponse(
            statusCode: 200,
            headers: [:],
            data: data
        ))

        let client = ClaudeUsageClient(transport: transport)
        let account = ClaudeAccountMetadata(
            id: "acct_test",
            label: "Test",
            organizationId: "org_test"
        )

        let result = try await client.fetchUsage(
            account: account,
            sessionKey: "sk-test",
            now: ISO8601DateFormatter().date(from: "2026-02-08T14:00:00Z")!
        )

        XCTAssertEqual(result.providerState.resetWindow?.resetsAt, weeklyResetAt)
    }
}

private struct StubTransport: ClaudeUsageHTTPTransport {
    let response: ClaudeUsageHTTPResponse

    func data(for request: URLRequest) async throws -> ClaudeUsageHTTPResponse {
        response
    }
}
