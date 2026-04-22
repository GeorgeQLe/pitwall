import Foundation
import XCTest
import PitwallCore
@testable import PitwallShared

/// Phase 5 Step 5.6 cross-platform regression anchor for the shared layer.
/// These tests pin the fixtures + contracts that both `PitwallWindowsTests`
/// and `PitwallLinuxTests` reuse: provider visibility filtering,
/// `ProviderHistoryRetention` windowing, `DiagnosticsRedactor` key set, and
/// the `GitHubHeatmapResponseMapper` recorded fixture. If either platform
/// drifts from these expectations the parallel platform suite fails.
final class CrossPlatformRegressionTests: XCTestCase {
    static let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    static func sharedSnapshot() -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            providerProfiles: [
                ProviderProfileConfiguration(providerId: .claude, isEnabled: true),
                ProviderProfileConfiguration(providerId: .codex, isEnabled: false),
                ProviderProfileConfiguration(providerId: .gemini, isEnabled: true)
            ],
            claudeAccounts: [
                ClaudeAccountConfiguration(
                    id: "acct-primary",
                    label: "Primary",
                    organizationId: "org-shared"
                )
            ],
            selectedClaudeAccountId: "acct-primary",
            userPreferences: UserPreferences(resetDisplayPreference: .countdown)
        )
    }

    func test_providerVisibility_disabledProvidersDoNotReachViewModel() async throws {
        let storage = InMemoryProviderConfigurationStorage()
        try await storage.save(Self.sharedSnapshot())
        let reloaded = await storage.load()

        let visible = reloaded.providerProfiles.filter(\.isEnabled).map(\.providerId)
        XCTAssertEqual(visible, [.claude, .gemini])
        XCTAssertFalse(visible.contains(.codex))
        XCTAssertEqual(reloaded.selectedClaudeAccountId, "acct-primary")
    }

    func test_providerHistoryRetention_windowsAndDownsamplesOnSharedFixture() {
        let now = Self.fixedNow
        let recent = ProviderHistorySnapshot(
            accountId: "acct-primary",
            recordedAt: now.addingTimeInterval(-30 * 60),
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 40,
            weeklyUtilizationPercent: 42,
            headline: "recent"
        )
        let downsampledA = ProviderHistorySnapshot(
            accountId: "acct-primary",
            recordedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 10,
            weeklyUtilizationPercent: 20,
            headline: "2d ago A"
        )
        let downsampledB = ProviderHistorySnapshot(
            accountId: "acct-primary",
            recordedAt: now.addingTimeInterval(-2 * 24 * 60 * 60 + 120),
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 80,
            weeklyUtilizationPercent: 25,
            headline: "2d ago B"
        )
        let expired = ProviderHistorySnapshot(
            accountId: "acct-primary",
            recordedAt: now.addingTimeInterval(-30 * 24 * 60 * 60),
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 1,
            weeklyUtilizationPercent: 1,
            headline: "expired"
        )

        let retained = ProviderHistoryRetention(now: now)
            .retainedSnapshots(from: [recent, downsampledA, downsampledB, expired])

        XCTAssertEqual(retained.count, 2)
        XCTAssertFalse(retained.contains { $0.headline == "expired" })
        XCTAssertTrue(retained.contains { $0.headline == "recent" })
        // Hour-bucket merged snapshot keeps the highest session utilization.
        let merged = retained.first { $0.recordedAt < now.addingTimeInterval(-24 * 60 * 60) }
        XCTAssertEqual(merged?.sessionUtilizationPercent, 80)
    }

    func test_diagnosticsRedactor_redactsKnownTokenKeys() {
        let redactor = DiagnosticsRedactor()
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .highConfidence,
            headline: "Bearer sk-abc123DEADBEEFabc123 tail",
            confidenceExplanation: "sessionKey=abc123def456 ghp_shouldDisappear"
        )
        let event = DiagnosticEvent(
            providerId: .claude,
            occurredAt: Self.fixedNow,
            summary: "token ghp_abc123DEADBEEF leaked",
            details: ["authorization": "Bearer sk-abc123DEADBEEFabc123"]
        )
        let built = DiagnosticsExportBuilder(
            appVersion: "1.0",
            buildNumber: "1",
            generatedAt: Self.fixedNow,
            enabledProviderIds: [.claude, .gemini],
            providerStates: [provider],
            storageHealth: StorageHealth(status: .healthy, lastSuccessfulWriteAt: Self.fixedNow),
            diagnosticEvents: [event],
            redactor: redactor
        ).build()

        let summary = built.providerSummaries[0]
        XCTAssertFalse(summary.headline.contains("sk-abc123"))
        XCTAssertFalse(summary.confidenceExplanation.contains("sessionKey=abc123def456"))
        XCTAssertFalse(summary.confidenceExplanation.contains("ghp_shouldDisappear"))

        let redactedEvent = built.diagnosticEvents[0]
        XCTAssertFalse(redactedEvent.summary.contains("ghp_abc123DEADBEEF"))
        for (_, value) in redactedEvent.details {
            XCTAssertFalse(value.contains("sk-abc123"))
        }
    }

    func test_githubHeatmapResponseMapper_producesIdenticalOutputForRecordedFixture() throws {
        let payload = Self.heatmapFixtureJSON
        let heatmap = try GitHubHeatmapResponseMapper().map(data: Data(payload.utf8), maxWeeks: 12)

        XCTAssertEqual(heatmap.weeks.count, 2)
        XCTAssertEqual(heatmap.weeks[0].days.map(\.date), ["2027-03-09", "2027-03-10"])
        XCTAssertEqual(heatmap.weeks[0].days.map(\.contributionCount), [1, 4])
        XCTAssertEqual(heatmap.weeks[1].days.map(\.contributionCount), [7, 0])
        XCTAssertEqual(heatmap.weeks[1].days.map(\.color), ["#216e39", "#ebedf0"])
    }

    static let heatmapFixtureJSON: String = """
    {
      "data": {
        "user": {
          "contributionsCollection": {
            "contributionCalendar": {
              "weeks": [
                {
                  "contributionDays": [
                    {"date":"2027-03-09","contributionCount":1,"color":"#9be9a8"},
                    {"date":"2027-03-10","contributionCount":4,"color":"#40c463"}
                  ]
                },
                {
                  "contributionDays": [
                    {"date":"2027-03-16","contributionCount":7,"color":"#216e39"},
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
}

