import Foundation
import XCTest
@testable import PitwallLinux

private final class FixtureProbe: LinuxGeminiFilesystemProbing, @unchecked Sendable {
    var available: Bool = true
    var files: [String: LinuxGeminiArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var inspectedPaths: [String] = []

    var isAvailable: Bool { available }

    func probe(relativePath: String) -> LinuxGeminiArtifactMetadata? {
        inspectedPaths.append(relativePath)
        return files[relativePath]
    }

    func childCount(relativeDirectory: String) -> Int {
        directoryCounts[relativeDirectory] ?? 0
    }
}

final class LinuxGeminiDetectorTests: XCTestCase {
    func test_detect_presenceOnly_returnsConfiguredArtifacts() {
        let probe = FixtureProbe()
        probe.files["settings.json"] = LinuxGeminiArtifactMetadata(
            relativePath: "settings.json",
            byteSize: 400,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        probe.files["oauth_creds.json"] = LinuxGeminiArtifactMetadata(
            relativePath: "oauth_creds.json",
            byteSize: 200,
            modifiedAtEpochSeconds: 1_700_000_100
        )
        probe.directoryCounts["tmp"] = 2

        let detector = LinuxGeminiDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )
        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        XCTAssertTrue(evidence.settingsDetected)
        XCTAssertTrue(evidence.authDetected)
        XCTAssertEqual(evidence.chatSessionCount, 2)
        XCTAssertEqual(probe.inspectedPaths.sorted(), ["oauth_creds.json", "settings.json"])
    }

    func test_detect_suppressedProbe_failsClosed() {
        let detector = LinuxGeminiDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: LinuxGeminiSuppressedProbe()
        )
        let evidence = detector.detect()

        XCTAssertTrue(evidence.suppressed)
        XCTAssertTrue(evidence.artifacts.isEmpty)
        XCTAssertEqual(evidence.chatSessionCount, 0)
    }

    func test_sanitization_dropsAbsolutePathsAndTokenSubstrings() {
        let probe = FixtureProbe()
        probe.files["oauth_creds.json"] = LinuxGeminiArtifactMetadata(
            relativePath: "/home/alice/.config/gemini/oauth_creds.json ya29.a0ARrdaM-SECRET",
            byteSize: 900,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        let detector = LinuxGeminiDetector(
            root: LinuxStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )

        let evidence = detector.detect()
        let stored = evidence.artifacts["oauth_creds.json"]
        XCTAssertEqual(stored?.relativePath, "oauth_creds.json")
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("/home/"))
            XCTAssertFalse(meta.relativePath.contains("ya29."))
        }
    }

    func test_xdgConfigRoot_honorsXDGOverride() {
        let override = LinuxGeminiDetector.xdgConfigRoot(
            xdgConfigHome: "/custom/xdg",
            home: "/home/alice"
        )
        XCTAssertEqual(override.rootDirectory.path, "/custom/xdg/gemini")
    }

    func test_xdgConfigRoot_fallsBackToHomeConfig() {
        let fallback = LinuxGeminiDetector.xdgConfigRoot(
            xdgConfigHome: nil,
            home: "/home/alice"
        )
        XCTAssertEqual(fallback.rootDirectory.path, "/home/alice/.config/gemini")
    }

    func test_injectedRoot_detectorDoesNotTouchRealHome() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(
            "pitwall-gemini-linux-\(UUID().uuidString)",
            isDirectory: true
        )
        let detector = LinuxGeminiDetector(
            root: LinuxStorageRoot(rootDirectory: tmp),
            probe: FixtureProbe()
        )
        _ = detector.detect()
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }
}
