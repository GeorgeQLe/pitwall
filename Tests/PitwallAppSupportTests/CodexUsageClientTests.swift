import XCTest
@testable import PitwallAppSupport

final class CodexUsageClientTests: XCTestCase {
    func testParserDecodesAppServerRateLimitResponse() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let data = Data(
            """
            {
              "rateLimits": {
                "limitId": "codex",
                "limitName": null,
                "primary": {
                  "usedPercent": 30,
                  "windowDurationMins": 300,
                  "resetsAt": 1777332336
                },
                "secondary": {
                  "usedPercent": 26,
                  "windowDurationMins": 10080,
                  "resetsAt": 1777402686
                },
                "credits": {
                  "hasCredits": false,
                  "unlimited": false,
                  "balance": "0"
                },
                "planType": "pro",
                "rateLimitReachedType": null
              },
              "rateLimitsByLimitId": {
                "codex_bengalfox": {
                  "limitId": "codex_bengalfox",
                  "limitName": "GPT-5.3-Codex-Spark",
                  "primary": {
                    "usedPercent": 0,
                    "windowDurationMins": 300,
                    "resetsAt": 1777343858
                  },
                  "secondary": {
                    "usedPercent": 0,
                    "windowDurationMins": 10080,
                    "resetsAt": 1777930658
                  },
                  "credits": null,
                  "planType": "pro",
                  "rateLimitReachedType": null
                },
                "codex": {
                  "limitId": "codex",
                  "limitName": null,
                  "primary": {
                    "usedPercent": 30,
                    "windowDurationMins": 300,
                    "resetsAt": 1777332336
                  },
                  "secondary": {
                    "usedPercent": 26,
                    "windowDurationMins": 10080,
                    "resetsAt": 1777402686
                  },
                  "credits": {
                    "hasCredits": false,
                    "unlimited": false,
                    "balance": "0"
                  },
                  "planType": "pro",
                  "rateLimitReachedType": null
                }
              }
            }
            """.utf8
        )

        let result = try CodexUsageClientParser().parse(data, fetchedAt: fetchedAt)

        XCTAssertEqual(result.fetchedAt, fetchedAt)
        XCTAssertEqual(result.preferredRateLimit.limitId, "codex")
        XCTAssertEqual(result.preferredRateLimit.primary?.usedPercent, 30)
        XCTAssertEqual(result.preferredRateLimit.primary?.windowDurationMinutes, 300)
        XCTAssertEqual(
            result.preferredRateLimit.primary?.resetsAt,
            Date(timeIntervalSince1970: 1_777_332_336)
        )
        XCTAssertEqual(result.preferredRateLimit.secondary?.usedPercent, 26)
        XCTAssertEqual(result.preferredRateLimit.credits?.balance, "0")
        XCTAssertEqual(result.rateLimitsByLimitId?["codex_bengalfox"]?.limitName, "GPT-5.3-Codex-Spark")
    }
}
