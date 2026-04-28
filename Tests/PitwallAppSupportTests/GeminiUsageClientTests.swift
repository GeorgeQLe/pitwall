import XCTest
@testable import PitwallAppSupport

final class GeminiUsageClientTests: XCTestCase {
    func testFetchUsageUsesExistingGeminiCLIAuthAndParsesQuotaBuckets() async throws {
        let root = try makeGeminiHome()
        try write(
            #"{"selectedAuthType":"oauth-personal","profile":"work"}"#,
            to: root.appendingPathComponent("settings.json")
        )
        try write(
            #"{"access_token":"access-token","refresh_token":"refresh-token","expiry_date":4102444800000}"#,
            to: root.appendingPathComponent("oauth_creds.json")
        )
        let transport = FakeGeminiTransport(responses: [
            GeminiUsageHTTPResponse(
                statusCode: 200,
                data: Data(#"{"cloudaicompanionProject":"cloud-ai-project","currentTier":"pro"}"#.utf8)
            ),
            GeminiUsageHTTPResponse(
                statusCode: 200,
                data: Data(
                    """
                    {
                      "quotaBuckets": [
                        {
                          "modelId": "gemini-2.5-pro",
                          "tokenType": "requests",
                          "remainingAmount": 750,
                          "remainingFraction": 0.75,
                          "resetTime": "2026-04-29T00:00:00Z"
                        }
                      ]
                    }
                    """.utf8
                )
            )
        ])
        let client = GeminiUsageClient(
            environment: ["GEMINI_HOME": root.path],
            transport: transport,
            codeAssistBaseURL: URL(string: "https://example.test")!
        )

        let result = try await client.fetchUsage(now: Date(timeIntervalSince1970: 1_700_000_000))
        let requests = await transport.requests

        XCTAssertEqual(result.projectId, "cloud-ai-project")
        XCTAssertEqual(result.tier, "pro")
        XCTAssertEqual(result.primaryBucket?.modelId, "gemini-2.5-pro")
        XCTAssertEqual(result.primaryBucket?.tokenType, "requests")
        XCTAssertEqual(result.primaryBucket?.remainingAmount, 750)
        XCTAssertEqual(result.primaryBucket?.remainingFraction, 0.75)
        XCTAssertEqual(result.primaryBucket?.usedPercent, 25)
        XCTAssertEqual(requests.map(\.url?.absoluteString), [
            "https://example.test/v1internal:loadCodeAssist",
            "https://example.test/v1internal:retrieveUserQuota"
        ])
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }

    func testFetchUsageRejectsUnsupportedAuthModeBeforeReadingOAuthCredential() async throws {
        let root = try makeGeminiHome()
        try write(
            #"{"selectedAuthType":"gemini-api-key"}"#,
            to: root.appendingPathComponent("settings.json")
        )
        let client = GeminiUsageClient(
            environment: ["GEMINI_HOME": root.path],
            transport: FakeGeminiTransport(responses: [])
        )

        do {
            _ = try await client.fetchUsage(now: Date(timeIntervalSince1970: 1_700_000_000))
            XCTFail("Expected unsupported auth mode.")
        } catch let error as GeminiUsageClientError {
            XCTAssertEqual(error, .unsupportedAuthMode("gemini-api-key"))
        }
    }

    func testFetchUsageRefreshesExpiredTokenUsingInstalledCliOAuthMetadata() async throws {
        let root = try makeGeminiHome()
        let oauthSource = root.appendingPathComponent("oauth2.js")
        try write(
            #"{"security":{"auth":{"selectedType":"oauth-personal"}}}"#,
            to: root.appendingPathComponent("settings.json")
        )
        try write(
            #"{"access_token":"expired-token","refresh_token":"refresh-token","expiry_date":1}"#,
            to: root.appendingPathComponent("oauth_creds.json")
        )
        try write(
            """
            const OAUTH_CLIENT_ID = 'client-id';
            const OAUTH_CLIENT_SECRET = 'client-secret';
            """,
            to: oauthSource
        )
        let transport = FakeGeminiTransport(responses: [
            GeminiUsageHTTPResponse(
                statusCode: 200,
                data: Data(#"{"access_token":"fresh-token"}"#.utf8)
            ),
            GeminiUsageHTTPResponse(
                statusCode: 200,
                data: Data(#"{"cloudaicompanionProject":"projects/cloud-ai-project","currentTier":{"id":"pro"}}"#.utf8)
            ),
            GeminiUsageHTTPResponse(
                statusCode: 200,
                data: Data(#"{"buckets":[{"remainingFraction":80,"resetTime":"2026-04-29T00:00:00Z"}]}"#.utf8)
            )
        ])
        let client = GeminiUsageClient(
            environment: [
                "GEMINI_HOME": root.path,
                "GEMINI_CLI_OAUTH2_PATH": oauthSource.path
            ],
            transport: transport,
            codeAssistBaseURL: URL(string: "https://example.test")!,
            tokenURL: URL(string: "https://oauth2.example.test/token")!
        )

        let result = try await client.fetchUsage(now: Date(timeIntervalSince1970: 1_700_000_000))
        let requests = await transport.requests

        XCTAssertEqual(result.projectId, "projects/cloud-ai-project")
        XCTAssertEqual(result.tier, "pro")
        XCTAssertEqual(result.primaryBucket?.remainingFraction, 0.8)
        XCTAssertEqual(result.primaryBucket?.usedPercent ?? 0, 20, accuracy: 0.0001)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://oauth2.example.test/token")
        XCTAssertEqual(requests.dropFirst().first?.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
    }

    private func makeGeminiHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PitwallGeminiUsageClientTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ content: String, to url: URL) throws {
        try content.data(using: .utf8)?.write(to: url)
    }
}

private actor FakeGeminiTransport: GeminiUsageHTTPTransport {
    private var responses: [GeminiUsageHTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [GeminiUsageHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> GeminiUsageHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw GeminiUsageClientError.networkUnavailable
        }
        return responses.removeFirst()
    }
}
