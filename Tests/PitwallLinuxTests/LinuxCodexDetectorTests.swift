import Foundation
import XCTest
@testable import PitwallLinux

private final class FixtureProbe: LinuxCodexFilesystemProbing, @unchecked Sendable {
    var available: Bool = true
    var files: [String: LinuxCodexArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var inspectedPaths: [String] = []

    var isAvailable: Bool { available }

    func probe(relativePath: String) -> LinuxCodexArtifactMetadata? {
        inspectedPaths.append(relativePath)
        return files[relativePath]
    }

    func childCount(relativeDirectory: String) -> Int {
        directoryCounts[relativeDirectory] ?? 0
    }
}

final class LinuxCodexDetectorTests: XCTestCase {
    func test_detect_presenceOnly_returnsConfiguredArtifacts() {
        let probe = FixtureProbe()
        probe.files["config.toml"] = LinuxCodexArtifactMetadata(
            relativePath: "config.toml",
            byteSize: 800,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        probe.files["history.jsonl"] = LinuxCodexArtifactMetadata(
            relativePath: "history.jsonl",
            byteSize: 2_048,
            modifiedAtEpochSeconds: 1_700_000_200
        )
        probe.directoryCounts["sessions"] = 2
        probe.directoryCounts["logs"] = 5

        let detector = LinuxCodexDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )
        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        XCTAssertTrue(evidence.configDetected)
        XCTAssertFalse(evidence.authDetected)
        XCTAssertTrue(evidence.historyDetected)
        XCTAssertEqual(evidence.sessionCount, 2)
        XCTAssertEqual(evidence.logCount, 5)
        XCTAssertEqual(probe.inspectedPaths.sorted(), ["auth.json", "config.toml", "history.jsonl"])
    }

    func test_detect_suppressedProbe_failsClosed() {
        let detector = LinuxCodexDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: LinuxCodexSuppressedProbe()
        )
        let evidence = detector.detect()

        XCTAssertTrue(evidence.suppressed)
        XCTAssertTrue(evidence.artifacts.isEmpty)
        XCTAssertEqual(evidence.sessionCount, 0)
        XCTAssertEqual(evidence.logCount, 0)
    }

    func test_sanitization_dropsAbsolutePathsAndTokenSubstrings() {
        let probe = FixtureProbe()
        probe.files["auth.json"] = LinuxCodexArtifactMetadata(
            relativePath: "/home/alice/.config/codex/auth.json sk-live-DEADBEEF1234",
            byteSize: 77,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        let detector = LinuxCodexDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )

        let evidence = detector.detect()
        let stored = evidence.artifacts["auth.json"]
        XCTAssertEqual(stored?.relativePath, "auth.json")
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("/home/"))
            XCTAssertFalse(meta.relativePath.lowercased().contains("sk-"))
        }
    }

    func test_xdgConfigRoot_honorsXDGOverride() {
        let override = LinuxCodexDetector.xdgConfigRoot(
            xdgConfigHome: "/custom/xdg",
            home: "/home/alice"
        )
        XCTAssertEqual(override.rootDirectory.path, "/custom/xdg/codex")
    }

    func test_xdgConfigRoot_fallsBackToHomeConfig() {
        let fallback = LinuxCodexDetector.xdgConfigRoot(
            xdgConfigHome: nil,
            home: "/home/alice"
        )
        XCTAssertEqual(fallback.rootDirectory.path, "/home/alice/.config/codex")
    }

    func test_injectedRoot_detectorDoesNotTouchRealHome() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(
            "pitwall-codex-linux-\(UUID().uuidString)",
            isDirectory: true
        )
        let detector = LinuxCodexDetector(
            root: LinuxStorageRoot(rootDirectory: tmp),
            probe: FixtureProbe()
        )
        _ = detector.detect()
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }
}
