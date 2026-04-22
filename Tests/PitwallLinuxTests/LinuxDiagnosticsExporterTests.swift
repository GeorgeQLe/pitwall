import Foundation
import XCTest
import PitwallCore
import PitwallShared
@testable import PitwallLinux

final class LinuxDiagnosticsExporterTests: XCTestCase {
    private var directory: URL!
    private var root: LinuxStorageRoot!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        root = LinuxStorageRoot(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func provider() -> ProviderState {
        ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .highConfidence,
            headline: "session ok",
            primaryValue: nil,
            secondaryValue: nil,
            resetWindow: nil,
            lastUpdatedAt: nil,
            pacingState: nil,
            confidenceExplanation: "",
            actions: [],
            payloads: []
        )
    }

    func test_export_writesJSONFileWithRedactedExport() throws {
        let now = Date(timeIntervalSince1970: 42)
        let exporter = LinuxDiagnosticsExporter(root: root, now: { now })
        let input = LinuxDiagnosticsInput(
            appVersion: "1.0",
            buildNumber: "42",
            enabledProviderIds: [.claude],
            providerStates: [provider()],
            storageHealth: StorageHealth(
                status: .healthy,
                lastSuccessfulWriteAt: now,
                summary: "ok"
            ),
            diagnosticEvents: []
        )

        let url = try exporter.export(input: input)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiagnosticsExport.self, from: data)
        XCTAssertEqual(decoded.enabledProviderIds, [.claude])
        XCTAssertEqual(decoded.providerSummaries.count, 1)
        XCTAssertEqual(decoded.generatedAt, now)
    }

    func test_build_appliesRedactorToProviderSummaries() {
        let exporter = LinuxDiagnosticsExporter(root: root)
        let provider = ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .highConfidence,
            headline: "Bearer sk-abc123 session ok",
            primaryValue: nil,
            secondaryValue: nil,
            resetWindow: nil,
            lastUpdatedAt: nil,
            pacingState: nil,
            confidenceExplanation: "sessionKey=abc123def456 noted",
            actions: [],
            payloads: []
        )
        let input = LinuxDiagnosticsInput(
            appVersion: "1.0",
            buildNumber: "1",
            enabledProviderIds: [.claude],
            providerStates: [provider],
            storageHealth: StorageHealth(
                status: .healthy,
                lastSuccessfulWriteAt: Date(),
                summary: nil
            ),
            diagnosticEvents: []
        )

        let export = exporter.build(input: input)
        let summary = export.providerSummaries[0]
        XCTAssertFalse(summary.headline.contains("sk-abc123"))
        XCTAssertFalse(summary.confidenceExplanation.contains("sessionKey=abc123def456"))
    }
}
