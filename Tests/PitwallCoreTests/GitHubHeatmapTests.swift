import XCTest
@testable import PitwallCore

final class GitHubHeatmapTests: XCTestCase {
    func testBuildsGraphQLRequestWithVariablesForLast12Weeks() throws {
        let now = try XCTUnwrap(Self.isoDate("2027-03-18T00:00:00Z"))

        let request = GitHubHeatmapRequest(
            username: "octocat",
            weeks: 12,
            now: now
        )

        XCTAssertFalse(request.query.contains("octocat"))
        XCTAssertTrue(request.query.contains("$userName"))
        XCTAssertTrue(request.query.contains("$from"))
        XCTAssertTrue(request.query.contains("$to"))
        XCTAssertEqual(request.variables["userName"] as? String, "octocat")
        XCTAssertEqual(request.variables["from"] as? String, "2026-12-24")
        XCTAssertEqual(request.variables["to"] as? String, "2027-03-18")
    }

    func testMapsLast12WeeksContributionCalendarResponse() throws {
        let payload = """
        {
          "data": {
            "user": {
              "contributionsCollection": {
                "contributionCalendar": {
                  "weeks": [
                    {
                      "contributionDays": [
                        {"date":"2027-03-16","contributionCount":3,"color":"#40c463"},
                        {"date":"2027-03-17","contributionCount":0,"color":"#ebedf0"}
                      ]
                    }
                  ]
                }
              }
            }
          }
        }
        """

        let heatmap = try GitHubHeatmapResponseMapper().map(data: Data(payload.utf8), maxWeeks: 12)

        XCTAssertEqual(heatmap.weeks.count, 1)
        XCTAssertEqual(heatmap.weeks[0].days.map(\.date), [
            "2027-03-16",
            "2027-03-17"
        ])
        XCTAssertEqual(heatmap.weeks[0].days.map(\.contributionCount), [3, 0])
    }

    func testRefreshLimiterBlocksAutomaticRefreshWithinOneHourButAllowsManualBypass() {
        let lastRefresh = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = GitHubHeatmapRefreshPolicy(minimumAutomaticRefreshInterval: 60 * 60)

        XCTAssertFalse(policy.shouldRefresh(lastRefreshAt: lastRefresh, now: lastRefresh.addingTimeInterval(30 * 60), trigger: .automatic))
        XCTAssertTrue(policy.shouldRefresh(lastRefreshAt: lastRefresh, now: lastRefresh.addingTimeInterval(30 * 60), trigger: .manual))
        XCTAssertTrue(policy.shouldRefresh(lastRefreshAt: lastRefresh, now: lastRefresh.addingTimeInterval(61 * 60), trigger: .automatic))
    }

    func testUnauthorizedResponsesBecomeInvalidTokenState() {
        XCTAssertEqual(GitHubHeatmapError.httpStatus(401).tokenState, .invalidOrExpired)
        XCTAssertEqual(GitHubHeatmapError.httpStatus(403).tokenState, .invalidOrExpired)
    }

    func testSavedGitHubTokenStateNeverRendersToken() async throws {
        let token = "ghp_sensitive_token"
        let store = InMemorySecretStore()
        let manager = GitHubHeatmapTokenManager(secretStore: store)

        let state = try await manager.saveToken(token, username: "octocat")
        let stored = try await store.loadSecret(for: GitHubHeatmapTokenManager.secretKey(username: "octocat"))

        XCTAssertEqual(stored, token)
        XCTAssertEqual(state.status, .configured)
        XCTAssertNil(state.renderedToken)
        XCTAssertFalse(String(describing: state).contains(token))
    }

    private static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
