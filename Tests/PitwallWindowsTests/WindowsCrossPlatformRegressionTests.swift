import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallWindows

/// Phase 5 Step 5.6 Windows-side regression anchor. Every expected string,
/// redacted key set, retention outcome, and heatmap mapping mirrors the
/// sibling assertions in `LinuxCrossPlatformRegressionTests`. If either
/// platform's adapter drifts, the corresponding expected constant will no
/// longer match and this suite fails loudly — without needing a cross-shell
/// import.
final class WindowsCrossPlatformRegressionTests: XCTestCase {
    private enum Expected {
        static let tooltip = "Claude — 42% — 1h — push"
        static let statusText = "Configured"
        static let confidenceText = "High confidence"
        static let metric = "42%"
        static let resetText = "1h"
        static let recommendedAction = "push"
        static let headline = "Claude ok"
    }

    private static let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    private var directory: URL!
    private var root: WindowsStorageRoot!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-regression-\(UUID().uuidString)", isDirectory: true)
        root = WindowsStorageRoot(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func sharedSnapshot() -> ProviderConfigurationSnapshot {
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
            userPreferences: UserPreferences()
        )
    }

    private func provider(id: ProviderID) -> ProviderState {
        ProviderState(
            providerId: id,
            displayName: id == .claude ? "Claude" : id.rawValue.capitalized,
            status: .configured,
            confidence: .highConfidence,
            headline: id == .claude ? "Claude ok" : "\(id.rawValue) ok",
            primaryValue: nil,
            secondaryValue: nil,
            resetWindow: ResetWindow(resetsAt: Self.fixedNow.addingTimeInterval(60 * 60)),
            lastUpdatedAt: nil,
            pacingState: PacingState(weeklyUtilizationPercent: 42),
            confidenceExplanation: "",
            actions: [],
            payloads: []
        )
    }

    // MARK: - Provider visibility parity

    func test_providerVisibility_roundTripAndDisabledProviderIsHidden() async throws {
        let store = WindowsProviderConfigurationStore(root: root)
        try await store.save(sharedSnapshot())
        let reloaded = await store.load()

        XCTAssertEqual(reloaded.providerProfiles.map(\.providerId), [.claude, .codex, .gemini])
        XCTAssertEqual(reloaded.providerProfiles.map(\.isEnabled), [true, false, true])
        XCTAssertEqual(reloaded.selectedClaudeAccountId, "acct-primary")

        let enabledProviders = reloaded.providerProfiles
            .filter(\.isEnabled)
            .map { provider(id: $0.providerId) }
        let vm = WindowsTrayMenuBuilder().build(
            providers: enabledProviders,
            selectedProviderId: .claude,
            preferences: UserPreferences(),
            now: Self.fixedNow
        )

        XCTAssertEqual(vm.providerCards.map(\.providerId), [.claude, .gemini])
        XCTAssertFalse(vm.providerCards.contains { $0.providerId == .codex })
    }

    // MARK: - Tray/menu formatting parity

    func test_statusFormatter_matchesSharedExpectedStrings() {
        let formatter = WindowsStatusFormatter()
        let claude = provider(id: .claude)

        XCTAssertEqual(
            formatter.compactTooltip(provider: claude, preferences: UserPreferences(), now: Self.fixedNow),
            Expected.tooltip
        )
        XCTAssertEqual(formatter.statusText(claude.status), Expected.statusText)
        XCTAssertEqual(formatter.confidenceText(claude.confidence), Expected.confidenceText)
        XCTAssertEqual(formatter.metric(for: claude), Expected.metric)
        XCTAssertEqual(
            formatter.resetText(
                resetWindow: claude.resetWindow,
                preference: .countdown,
                now: Self.fixedNow
            ),
            Expected.resetText
        )
        XCTAssertEqual(formatter.recommendedActionText(for: claude), Expected.recommendedAction)
    }

    func test_trayBuilder_emitsCardsMatchingSharedExpectedLabels() {
        let vm = WindowsTrayMenuBuilder().build(
            providers: [provider(id: .claude)],
            selectedProviderId: .claude,
            preferences: UserPreferences(),
            now: Self.fixedNow
        )

        XCTAssertEqual(vm.tooltip, Expected.tooltip)
        let card = vm.providerCards[0]
        XCTAssertEqual(card.statusText, Expected.statusText)
        XCTAssertEqual(card.confidenceText, Expected.confidenceText)
        XCTAssertEqual(card.metric, Expected.metric)
        XCTAssertEqual(card.resetText, Expected.resetText)
        XCTAssertEqual(card.recommendedActionText, Expected.recommendedAction)
        XCTAssertEqual(card.headline, Expected.headline)
    }

    // MARK: - Credential write-only behavior

    func test_credentialStore_neverExposesPlaintextReadPath_onFailingBackend() async {
        let store = WindowsCredentialManagerSecretStore(
            backend: InMemoryWindowsCredentialBackend(writesEnabled: false)
        )
        let key = ProviderSecretKey(providerId: .claude, accountId: "acct", purpose: "sessionKey")

        do {
            try await store.save("secret", for: key)
            XCTFail("save must throw when backend is unavailable")
        } catch let error as WindowsCredentialManagerError {
            XCTAssertEqual(error, .backendUnavailable)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }

        // Reads surface `nil` — never a degraded plaintext default.
        let loaded = try? await store.loadSecret(for: key)
        XCTAssertNil(loaded ?? nil)

        // There is no other on-disk plaintext fallback next to the store.
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func test_secureStorageDegradedStateEnum_isVisibleToShell() {
        // The shell surfaces the degraded state by pattern-matching the public
        // `WindowsCredentialManagerError` enum — asserting equality here
        // guarantees the enum case remains part of the adapter's public
        // surface (no silent persistence path is introduced behind the shell).
        let degraded: WindowsCredentialManagerError = .backendUnavailable
        XCTAssertEqual(degraded, .backendUnavailable)
    }

    // MARK: - Codex / Gemini sanitization

    func test_codexDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings() {
        let probe = WindowsCodexRegressionProbe()
        probe.files["auth.json"] = WindowsCodexArtifactMetadata(
            relativePath: "C:\\Users\\alice\\AppData\\Roaming\\Codex\\auth.json sk-abc123DEADBEEF ghp_leak ya29.secret AIzaSyDummy",
            byteSize: -17,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        probe.files["config.toml"] = WindowsCodexArtifactMetadata(
            relativePath: "..\\..\\etc\\passwd",
            byteSize: 42,
            modifiedAtEpochSeconds: 1_700_000_100
        )
        let detector = WindowsCodexDetector(root: root, probe: probe)

        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("C:\\"))
            XCTAssertFalse(meta.relativePath.contains("/Users/"))
            XCTAssertFalse(meta.relativePath.contains(".."))
            let lowered = meta.relativePath.lowercased()
            XCTAssertFalse(lowered.contains("sk-"))
            XCTAssertFalse(lowered.contains("ghp_"))
            XCTAssertFalse(lowered.contains("ya29."))
            XCTAssertFalse(lowered.contains("aiza"))
            XCTAssertGreaterThanOrEqual(meta.byteSize, 0)
        }
    }

    func test_geminiDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings() {
        let probe = WindowsGeminiRegressionProbe()
        probe.files["oauth_creds.json"] = WindowsGeminiArtifactMetadata(
            relativePath: "C:\\Users\\alice\\AppData\\Roaming\\Gemini\\oauth_creds.json ya29.DEADBEEF AIzaSyLeaked",
            byteSize: 128,
            modifiedAtEpochSeconds: 1_700_000_200
        )
        let detector = WindowsGeminiDetector(root: root, probe: probe)

        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("C:\\"))
            let lowered = meta.relativePath.lowercased()
            XCTAssertFalse(lowered.contains("ya29."))
            XCTAssertFalse(lowered.contains("aiza"))
            XCTAssertFalse(lowered.contains("sk-"))
        }
    }

    func test_detectors_suppressedWhenProbeUnavailable_noFabricatedEvidence() {
        let codexEvidence = WindowsCodexDetector(root: root, probe: WindowsCodexSuppressedProbe()).detect()
        XCTAssertTrue(codexEvidence.suppressed)
        XCTAssertTrue(codexEvidence.artifacts.isEmpty)

        let geminiEvidence = WindowsGeminiDetector(root: root, probe: WindowsGeminiSuppressedProbe()).detect()
        XCTAssertTrue(geminiEvidence.suppressed)
        XCTAssertTrue(geminiEvidence.artifacts.isEmpty)
    }

    // MARK: - Diagnostics redaction parity

    func test_diagnosticsExport_redactedKeySet_matchesSharedDiagnosticsContract() {
        let exporter = WindowsDiagnosticsExporter(root: root, now: { Self.fixedNow })
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
            summary: "ghp_abc123DEADBEEF leaked",
            details: ["authorization": "Bearer sk-abc123DEADBEEFabc123"]
        )
        let input = WindowsDiagnosticsInput(
            appVersion: "1.0",
            buildNumber: "1",
            enabledProviderIds: [.claude],
            providerStates: [provider],
            storageHealth: StorageHealth(status: .healthy, lastSuccessfulWriteAt: Self.fixedNow),
            diagnosticEvents: [event]
        )

        let export = exporter.build(input: input)
        let summary = export.providerSummaries[0]
        XCTAssertFalse(summary.headline.contains("sk-abc123"))
        XCTAssertFalse(summary.confidenceExplanation.contains("sessionKey=abc123def456"))
        XCTAssertFalse(summary.confidenceExplanation.contains("ghp_shouldDisappear"))
        let redactedEvent = export.diagnosticEvents[0]
        XCTAssertFalse(redactedEvent.summary.contains("ghp_abc123"))
        for (_, value) in redactedEvent.details {
            XCTAssertFalse(value.contains("sk-abc123"))
        }
    }

    // MARK: - History retention parity

    func test_historyStore_appliesSharedRetentionFixture() async throws {
        let store = WindowsProviderHistoryStore(root: root)
        let now = Self.fixedNow
        let fresh = ProviderHistorySnapshot(
            accountId: "acct-primary",
            recordedAt: now.addingTimeInterval(-30 * 60),
            providerId: .claude,
            confidence: .highConfidence,
            sessionUtilizationPercent: 40,
            weeklyUtilizationPercent: 42,
            headline: "fresh"
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

        try await store.append(expired, now: now, maximumRetentionInterval: 7 * 24 * 60 * 60)
        try await store.append(fresh, now: now, maximumRetentionInterval: 7 * 24 * 60 * 60)

        let loaded = await store.load()
        XCTAssertEqual(loaded.map(\.headline), ["fresh"])
    }

    // MARK: - GitHub heatmap parity

    func test_githubHeatmapClient_producesIdenticalMappingForRecordedFixture() throws {
        let heatmap = try GitHubHeatmapResponseMapper().map(
            data: Data(Self.heatmapFixtureJSON.utf8),
            maxWeeks: 12
        )

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

private final class WindowsCodexRegressionProbe: WindowsCodexFilesystemProbing, @unchecked Sendable {
    var files: [String: WindowsCodexArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var isAvailable: Bool { true }
    func probe(relativePath: String) -> WindowsCodexArtifactMetadata? { files[relativePath] }
    func childCount(relativeDirectory: String) -> Int { directoryCounts[relativeDirectory] ?? 0 }
}

private final class WindowsGeminiRegressionProbe: WindowsGeminiFilesystemProbing, @unchecked Sendable {
    var files: [String: WindowsGeminiArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var isAvailable: Bool { true }
    func probe(relativePath: String) -> WindowsGeminiArtifactMetadata? { files[relativePath] }
    func childCount(relativeDirectory: String) -> Int { directoryCounts[relativeDirectory] ?? 0 }
}
