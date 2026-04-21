import XCTest
@testable import PitwallCore

final class ClaudeUsageParserTests: XCTestCase {
    func testParsesKnownUsageFieldsWithFriendlyLabelsAndUTCResetDates() throws {
        let response = try parser.parse(fixtureData(named: "complete_usage"))

        XCTAssertEqual(response.sections.map(\.key), [
            "five_hour",
            "seven_day",
            "seven_day_sonnet",
            "seven_day_opus",
            "seven_day_oauth_apps",
            "seven_day_cowork"
        ])
        XCTAssertEqual(response.sections.map(\.label), [
            "Session",
            "Weekly",
            "Sonnet",
            "Opus",
            "OAuth apps",
            "Cowork"
        ])

        let session = try XCTUnwrap(response.sections.first { $0.key == "five_hour" })
        XCTAssertEqual(session.utilizationPercent, 17.0, accuracy: 0.001)
        XCTAssertEqual(session.resetsAt, isoDate("2026-02-08T18:59:59Z"))

        let sonnet = try XCTUnwrap(response.sections.first { $0.key == "seven_day_sonnet" })
        XCTAssertEqual(sonnet.utilizationPercent, 0.0, accuracy: 0.001)
        XCTAssertNil(sonnet.resetsAt)
    }

    func testIgnoresNullUsageSections() throws {
        let response = try parser.parse(fixtureData(named: "null_sections_usage"))

        XCTAssertEqual(response.sections.map(\.key), ["seven_day"])
        XCTAssertEqual(response.sections.first?.label, "Weekly")
        XCTAssertEqual(response.sections.first?.utilizationPercent, 23.0)
    }

    func testToleratesUnknownSectionsWithoutSurfacingThemAsKnownUsageRows() throws {
        let response = try parser.parse(fixtureData(named: "unknown_sections_usage"))

        XCTAssertEqual(response.sections.map(\.key), ["five_hour", "seven_day"])
        XCTAssertTrue(response.unknownSectionKeys.contains("iguana_necktie"))
        XCTAssertTrue(response.unknownSectionKeys.contains("future_limit_shape"))
    }

    func testExposesExtraUsageWhenPresent() throws {
        let response = try parser.parse(fixtureData(named: "extra_usage"))
        let extraUsage = try XCTUnwrap(response.extraUsage)

        XCTAssertEqual(extraUsage.label, "Extra usage")
        XCTAssertTrue(extraUsage.isEnabled)
        XCTAssertEqual(extraUsage.monthlyLimit, 250.0, accuracy: 0.001)
        XCTAssertEqual(extraUsage.usedCredits, 37.5, accuracy: 0.001)
        XCTAssertEqual(extraUsage.utilizationPercent, 15.0, accuracy: 0.001)
    }

    func testAuthErrorNormalizationKeepsNonSecretAccountMetadata() {
        let account = ClaudeAccountMetadata(
            id: "acct_123",
            label: "Work Claude",
            organizationId: "org_abc",
            lastSuccessfulRefreshAt: isoDate("2026-02-08T18:00:00Z")
        )

        let state = ClaudeUsageParser.normalizedErrorState(
            for: .httpStatus(403),
            account: account,
            lastSuccessfulSnapshot: nil,
            now: isoDate("2026-02-08T19:00:00Z")
        )

        XCTAssertEqual(state.providerId, .claude)
        XCTAssertEqual(state.status, .expired)
        XCTAssertEqual(state.confidence, .observedOnly)
        XCTAssertEqual(state.lastUpdatedAt, account.lastSuccessfulRefreshAt)
        XCTAssertEqual(state.payloads.first?.values["accountLabel"], "Work Claude")
        XCTAssertNil(state.payloads.first?.values["sessionKey"])
        XCTAssertTrue(state.actions.contains { $0.kind == .openSettings && $0.isEnabled })
    }

    func testNetworkErrorNormalizationKeepsLastSuccessfulNonSecretSnapshotVisible() {
        let account = ClaudeAccountMetadata(
            id: "acct_123",
            label: "Work Claude",
            organizationId: "org_abc",
            lastSuccessfulRefreshAt: isoDate("2026-02-08T18:00:00Z")
        )
        let snapshot = ClaudeUsageSnapshot(
            recordedAt: isoDate("2026-02-08T18:00:00Z"),
            weeklyUtilizationPercent: 58.0,
            weeklyResetAt: isoDate("2026-02-14T16:59:59Z")
        )

        let state = ClaudeUsageParser.normalizedErrorState(
            for: .networkUnavailable,
            account: account,
            lastSuccessfulSnapshot: snapshot,
            now: isoDate("2026-02-08T19:00:00Z")
        )

        XCTAssertEqual(state.providerId, .claude)
        XCTAssertEqual(state.status, .stale)
        XCTAssertEqual(state.confidence, .estimated)
        XCTAssertEqual(state.primaryValue, "58%")
        XCTAssertEqual(state.resetWindow?.resetsAt, snapshot.weeklyResetAt)
        XCTAssertFalse(state.payloads.contains { payload in
            payload.values.values.contains { $0.contains("sk-ant") || $0.contains("sessionKey") }
        })
    }

    private var parser: ClaudeUsageParser {
        ClaudeUsageParser()
    }

    private func fixtureData(named name: String) throws -> Data {
        let currentFile = URL(fileURLWithPath: #filePath)
        let url = currentFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Claude/\(name).json")
        return try Data(contentsOf: url)
    }

    private func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
