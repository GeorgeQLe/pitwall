import Foundation
import XCTest
@testable import PitwallWindows

private final class FixtureProbe: WindowsGeminiFilesystemProbing, @unchecked Sendable {
    var available: Bool = true
    var files: [String: WindowsGeminiArtifactMetadata] = [:]
    var directoryCounts: [String: Int] = [:]
    var inspectedPaths: [String] = []

    var isAvailable: Bool { available }

    func probe(relativePath: String) -> WindowsGeminiArtifactMetadata? {
        inspectedPaths.append(relativePath)
        return files[relativePath]
    }

    func childCount(relativeDirectory: String) -> Int {
        directoryCounts[relativeDirectory] ?? 0
    }
}

final class WindowsGeminiDetectorTests: XCTestCase {
    func test_detect_presenceOnly_returnsConfiguredArtifacts() {
        let probe = FixtureProbe()
        probe.files["settings.json"] = WindowsGeminiArtifactMetadata(
            relativePath: "settings.json",
            byteSize: 512,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        probe.files["oauth_creds.json"] = WindowsGeminiArtifactMetadata(
            relativePath: "oauth_creds.json",
            byteSize: 128,
            modifiedAtEpochSeconds: 1_700_000_100
        )
        probe.directoryCounts["tmp"] = 4

        let detector = WindowsGeminiDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )
        let evidence = detector.detect()

        XCTAssertFalse(evidence.suppressed)
        XCTAssertTrue(evidence.settingsDetected)
        XCTAssertTrue(evidence.authDetected)
        XCTAssertEqual(evidence.chatSessionCount, 4)
        XCTAssertEqual(probe.inspectedPaths.sorted(), ["oauth_creds.json", "settings.json"])
    }

    func test_detect_suppressedProbe_failsClosed() {
        let detector = WindowsGeminiDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: WindowsGeminiSuppressedProbe()
        )
        let evidence = detector.detect()

        XCTAssertTrue(evidence.suppressed)
        XCTAssertTrue(evidence.artifacts.isEmpty)
        XCTAssertEqual(evidence.chatSessionCount, 0)
    }

    func test_sanitization_dropsAbsolutePathsAndTokenSubstrings() {
        let probe = FixtureProbe()
        probe.files["oauth_creds.json"] = WindowsGeminiArtifactMetadata(
            relativePath: "C:\\Users\\alice\\AppData\\Roaming\\Gemini\\oauth_creds.json ya29.a0ARrdaM-SECRET",
            byteSize: 900,
            modifiedAtEpochSeconds: 1_700_000_000
        )
        let detector = WindowsGeminiDetector(
            root: WindowsStorageRoot(rootDirectory: URL(fileURLWithPath: "/tmp/injected")),
            probe: probe
        )

        let evidence = detector.detect()
        let stored = evidence.artifacts["oauth_creds.json"]
        XCTAssertEqual(stored?.relativePath, "oauth_creds.json")
        for (_, meta) in evidence.artifacts {
            XCTAssertFalse(meta.relativePath.contains("C:\\"))
            XCTAssertFalse(meta.relativePath.contains("/Users/"))
            XCTAssertFalse(meta.relativePath.contains("ya29."))
        }
    }

    func test_injectedRoot_detectorDoesNotReachRealAppData() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(
            "pitwall-gemini-win-\(UUID().uuidString)",
            isDirectory: true
        )
        let probe = FixtureProbe()
        let detector = WindowsGeminiDetector(
            root: WindowsStorageRoot(rootDirectory: tmp),
            probe: probe
        )
        _ = detector.detect()
        XCTAssertEqual(detector.root.rootDirectory, tmp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }

    func test_roamingRoot_resolvesUnderAppData() {
        let root = WindowsGeminiDetector.roamingRoot(appDataPath: "C:\\Users\\alice\\AppData\\Roaming")
        XCTAssertTrue(root.rootDirectory.path.hasSuffix("Gemini"))
    }
}
