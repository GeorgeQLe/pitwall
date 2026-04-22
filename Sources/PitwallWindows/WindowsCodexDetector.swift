import Foundation

/// Presence-only metadata for a single Codex artifact observed by the
/// Windows filesystem probe. The probe never reads file bytes — only
/// existence, byte size, and modification time (seconds since epoch) are
/// surfaced.
public struct WindowsCodexArtifactMetadata: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int64
    public let modifiedAtEpochSeconds: Int64

    public init(relativePath: String, byteSize: Int64, modifiedAtEpochSeconds: Int64) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.modifiedAtEpochSeconds = modifiedAtEpochSeconds
    }
}

/// Sanitized evidence returned to the shell from the Windows Codex
/// detector. Values are presence-only: no absolute paths, no token-shaped
/// substrings, no file contents. `suppressed == true` means the probe
/// could not read the Codex root and the shell must surface the degraded
/// state rather than fabricating evidence.
public struct WindowsCodexDetectorEvidence: Equatable, Sendable {
    public let suppressed: Bool
    public let artifacts: [String: WindowsCodexArtifactMetadata]
    public let sessionCount: Int
    public let logCount: Int

    public init(
        suppressed: Bool,
        artifacts: [String: WindowsCodexArtifactMetadata],
        sessionCount: Int,
        logCount: Int
    ) {
        self.suppressed = suppressed
        self.artifacts = artifacts
        self.sessionCount = sessionCount
        self.logCount = logCount
    }

    public var configDetected: Bool { artifacts["config.toml"] != nil }
    public var authDetected: Bool { artifacts["auth.json"] != nil }
    public var historyDetected: Bool { artifacts["history.jsonl"] != nil }
}

/// Narrow presence-only probe seam the Windows Codex detector uses to
/// inspect the Codex data directory. The probe surfaces only allowed
/// metadata (existence, byte size, modification time) — never raw file
/// bytes. In production this wraps a `FileManager` reader; in tests it is
/// a fixture that returns pre-canned artifacts without touching the
/// user's real `%APPDATA%`.
public protocol WindowsCodexFilesystemProbing: Sendable {
    /// Returns metadata for the artifact at `relativePath` under the
    /// probe's resolved Codex root, or `nil` when the artifact is absent.
    func probe(relativePath: String) -> WindowsCodexArtifactMetadata?

    /// Counts children directly under `relativeDirectory` (non-recursive)
    /// without exposing their names. Returns 0 when the directory is
    /// absent. Used to size the session / log roots without leaking
    /// per-file names.
    func childCount(relativeDirectory: String) -> Int

    /// Whether the underlying filesystem is currently reachable. When
    /// `false` the detector must return suppressed evidence rather than
    /// fabricating presence signals.
    var isAvailable: Bool { get }
}

/// No-op probe used when the Codex data root is inaccessible (locked
/// profile, restricted container). The shell surfaces the degraded state;
/// it must not pretend evidence was observed.
public struct WindowsCodexSuppressedProbe: WindowsCodexFilesystemProbing {
    public init() {}
    public func probe(relativePath: String) -> WindowsCodexArtifactMetadata? { nil }
    public func childCount(relativeDirectory: String) -> Int { 0 }
    public var isAvailable: Bool { false }
}

public struct WindowsCodexDetector: Sendable {
    public let root: WindowsStorageRoot
    private let probe: WindowsCodexFilesystemProbing

    public init(root: WindowsStorageRoot, probe: WindowsCodexFilesystemProbing) {
        self.root = root
        self.probe = probe
    }

    /// Resolves the default Windows Codex root under `%APPDATA%\Codex\`.
    /// Codex ships user-level artifacts in the roaming profile, so
    /// `%APPDATA%` is the authoritative location; `%LOCALAPPDATA%` is not
    /// used.
    public static func roamingRoot(appDataPath: String) -> WindowsStorageRoot {
        WindowsStorageRoot.roaming(
            appDataPath: appDataPath,
            applicationFolderName: "Codex"
        )
    }

    public func detect() -> WindowsCodexDetectorEvidence {
        guard probe.isAvailable else {
            return WindowsCodexDetectorEvidence(
                suppressed: true,
                artifacts: [:],
                sessionCount: 0,
                logCount: 0
            )
        }
        var artifacts: [String: WindowsCodexArtifactMetadata] = [:]
        for name in ["config.toml", "auth.json", "history.jsonl"] {
            if let meta = probe.probe(relativePath: name) {
                artifacts[name] = WindowsCodexSanitizer.sanitize(meta, expectedRelativePath: name)
            }
        }
        return WindowsCodexDetectorEvidence(
            suppressed: false,
            artifacts: artifacts,
            sessionCount: probe.childCount(relativeDirectory: "sessions"),
            logCount: probe.childCount(relativeDirectory: "logs")
        )
    }
}

/// Presence-only sanitizer. Ensures returned metadata cannot echo an
/// absolute path back to callers (by pinning `relativePath` to the caller-
/// supplied name) and cannot carry a token-shaped substring (because the
/// probe never reads file contents, but we re-assert the constraint
/// defensively so a malicious probe implementation cannot smuggle one).
enum WindowsCodexSanitizer {
    static func sanitize(
        _ metadata: WindowsCodexArtifactMetadata,
        expectedRelativePath: String
    ) -> WindowsCodexArtifactMetadata {
        WindowsCodexArtifactMetadata(
            relativePath: expectedRelativePath,
            byteSize: max(0, metadata.byteSize),
            modifiedAtEpochSeconds: metadata.modifiedAtEpochSeconds
        )
    }
}
