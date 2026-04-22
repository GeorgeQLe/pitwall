import Foundation
import XCTest
@testable import PitwallWindows

private final class FixtureProbe: WindowsCodexFilesystemProbing, @unchecked Sendable {
    var available: Bool = true
    var files: [String: WindowsCodexArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var inspectedPaths: [String] = []

    var isAvailable: Bool { available }

    func probe(relativePath: String) -> WindowsCodexArtifactMetadata? {
        inspectedPaths.append(relativePath)
        return files[relativePath]
    }

    func childCount(relativeDirectory: String) -> Int {
        directoryCounts[relativeDirectory] ?? 0
    }
}

final class WindowsCodexDetectorTests: XCTestCase {
    func test_detect_presenceOnly_returnsConfiguredArtifacts() {
        let probe = FixtureProbe()
        probe.files["config.toml"] = WindowsCodexArtifactMetadata(
            relativePath: "config.toml",
            byteSize: 1_024,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        probe.files["auth.json"] = WindowsCodexArtifactMetadata(
            relativePath: "auth.json",
            byteSize: 256,
            modifiedAtEpochSeconds: 1_700_000_100
        )
        probe.directoryCounts["sessions"] = 3
        probe.directoryCounts["logs"] = 1

        let detector = WindowsCodexDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )
        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        XCTAssertTrue(evidence.configDetected)
        XCTAssertTrue(evidence.authDetected)
        XCTAssertFalse(evidence.historyDetected)
        XCTAssertEqual(evidence.sessionCount, 3)
        XCTAssertEqual(evidence.logCount, 1)
        XCTAssertEqual(probe.inspectedPaths.sorted(), ["auth.json", "config.toml", "history.jsonl"])
    }

    func test_detect_suppressedProbe_failsClosed() {
        let detector = WindowsCodexDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: WindowsCodexSuppressedProbe()
        )
        let evidence = detector.detect()

        XCTAssertTrue(evidence.suppressed)
        XCTAssertTrue(evidence.artifacts.isEmpty)
        XCTAssertEqual(evidence.sessionCount, 0)
        XCTAssertEqual(evidence.logCount, 0)
    }

    func test_sanitization_dropsAbsolutePathsAndTokenSubstrings() {
        let probe = FixtureProbe()
        probe.files["auth.json"] = WindowsCodexArtifactMetadata(
            relativePath: "C:\\Users\\alice\\AppData\\Roaming\\Codex\\auth.json sk-abc123DEADBEEFabc123",
            byteSize: 77,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        let detector = WindowsCodexDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )

        let evidence = detector.detect()
        let stored = evidence.artifacts["auth.json"]
        XCTAssertEqual(stored?.relativePath, "auth.json")
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("C:\\"))
            XCTAssertFalse(meta.relativePath.contains("/Users/"))
            XCTAssertFalse(meta.relativePath.lowercased().contains("sk-"))
        }
    }

    func test_injectedRoot_detectorDoesNotReachRealAppData() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(
            "pitwall-codex-win-\(UUID().uuidString)",
            isDirectory: true
        )
        let probe = FixtureProbe()
        let detector = WindowsCodexDetector(
            root: WindowsStorageRoot(rootDirectory: tmp),
            probe: probe
        )
        _ = detector.detect()
        XCTAssertEqual(detector.root.rootDirectory, tmp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }

    func test_roamingRoot_resolvesUnderAppData() {
        let root = WindowsCodexDetector.roamingRoot(appDataPath: "C:\\Users\\alice\\AppData\\Roaming")
        XCTAssertTrue(root.rootDirectory.path.hasSuffix("Codex"))
    }

    func test_negativeSizes_clampToZero() {
        let sanitized = WindowsCodexSanitizer.sanitize(
            WindowsCodexArtifactMetadata(
                relativePath: "auth.json",
                byteSize: -42,
                modifiedAtEpochSeconds: 10
            ),
            expectedRelativePath: "auth.json"
        )
        XCTAssertEqual(sanitized.byteSize, 0)
    }
}
