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

    func testPreferredRateLimitUsesTopLevelSlashStatusPayloadWhenBucketMapDiffers() {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let result = CodexUsageClientResult(
            rateLimits: CodexRateLimitSnapshot(
                limitId: "codex",
                primary: CodexRateLimitWindow(
                    usedPercent: 61,
                    windowDurationMinutes: 300,
                    resetsAt: fetchedAt.addingTimeInterval(60 * 60)
                ),
                secondary: CodexRateLimitWindow(
                    usedPercent: 44,
                    windowDurationMinutes: 10_080,
                    resetsAt: fetchedAt.addingTimeInterval(4 * 24 * 60 * 60)
                ),
                planType: "pro"
            ),
            rateLimitsByLimitId: [
                "codex": CodexRateLimitSnapshot(
                    limitId: "codex",
                    primary: CodexRateLimitWindow(
                        usedPercent: 12,
                        windowDurationMinutes: 300,
                        resetsAt: fetchedAt.addingTimeInterval(5 * 60 * 60)
                    ),
                    secondary: CodexRateLimitWindow(
                        usedPercent: 8,
                        windowDurationMinutes: 10_080,
                        resetsAt: fetchedAt.addingTimeInterval(6 * 24 * 60 * 60)
                    ),
                    planType: "pro"
                )
            ],
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(result.preferredRateLimit.primary?.usedPercent, 61)
        XCTAssertEqual(result.preferredRateLimit.secondary?.usedPercent, 44)
        XCTAssertEqual(result.preferredRateLimit.primary?.resetsAt, fetchedAt.addingTimeInterval(60 * 60))
    }
}
