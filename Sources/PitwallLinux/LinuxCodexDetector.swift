import Foundation

/// Presence-only metadata for a single Codex artifact observed by the
/// Linux filesystem probe. The probe never reads file bytes — only
/// existence, byte size, and modification time (seconds since epoch) are
/// surfaced.
public struct LinuxCodexArtifactMetadata: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int64
    public let modifiedAtEpochSeconds: Int64

    public init(relativePath: String, byteSize: Int64, modifiedAtEpochSeconds: Int64) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.modifiedAtEpochSeconds = modifiedAtEpochSeconds
    }
}

/// Sanitized evidence returned to the shell from the Linux Codex
/// detector. Values are presence-only: no absolute paths, no token-shaped
/// substrings, no file contents. `suppressed == true` means the probe
/// could not read the Codex root and the shell must surface the degraded
/// state rather than fabricating evidence.
public struct LinuxCodexDetectorEvidence: Equatable, Sendable {
    public let suppressed: Bool
    public let artifacts: [String: LinuxCodexArtifactMetadata]
    public let sessionCount: Int
    public let logCount: Int

    public init(
        suppressed: Bool,
        artifacts: [String: LinuxCodexArtifactMetadata],
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

public protocol LinuxCodexFilesystemProbing: Sendable {
    func probe(relativePath: String) -> LinuxCodexArtifactMetadata?
    func childCount(relativeDirectory: String) -> Int
    var isAvailable: Bool { get }
}

public struct LinuxCodexSuppressedProbe: LinuxCodexFilesystemProbing {
    public init() {}
    public func probe(relativePath: String) -> LinuxCodexArtifactMetadata? { nil }
    public func childCount(relativeDirectory: String) -> Int { 0 }
    public var isAvailable: Bool { false }
}

public struct LinuxCodexDetector: Sendable {
    public let root: LinuxStorageRoot
    private let probe: LinuxCodexFilesystemProbing

    public init(root: LinuxStorageRoot, probe: LinuxCodexFilesystemProbing) {
        self.root = root
        self.probe = probe
    }

    /// Resolves the default Codex root under `$XDG_CONFIG_HOME/codex/`
    /// with a `~/.config/codex/` fallback, honoring XDG env overrides
    /// only at the shell boundary (the detector protocol itself takes an
    /// already-resolved root). `$XDG_DATA_HOME` is not used because all
    /// Codex user-level artifacts (`config.toml`, `auth.json`,
    /// `history.jsonl`, `sessions/`) live under `$XDG_CONFIG_HOME`.
    public static func xdgConfigRoot(xdgConfigHome: String?, home: String) -> LinuxStorageRoot {
        LinuxStorageRoot.xdgConfig(
            xdgConfigHome: xdgConfigHome,
            home: home,
            applicationFolderName: "codex"
        )
    }

    public func detect() -> LinuxCodexDetectorEvidence {
        guard probe.isAvailable else {
            return LinuxCodexDetectorEvidence(
                suppressed: true,
                artifacts: [:],
                sessionCount: 0,
                logCount: 0
            )
        }
        var artifacts: [String: LinuxCodexArtifactMetadata] = [:]
        for name in ["config.toml", "auth.json", "history.jsonl"] {
            if let meta = probe.probe(relativePath: name) {
                artifacts[name] = LinuxCodexSanitizer.sanitize(meta, expectedRelativePath: name)
            }
        }
        return LinuxCodexDetectorEvidence(
            suppressed: false,
            artifacts: artifacts,
            sessionCount: probe.childCount(relativeDirectory: "sessions"),
            logCount: probe.childCount(relativeDirectory: "logs")
        )
    }
}

enum LinuxCodexSanitizer {
    static func sanitize(
        _ metadata: LinuxCodexArtifactMetadata,
        expectedRelativePath: String
    ) -> LinuxCodexArtifactMetadata {
        LinuxCodexArtifactMetadata(
            relativePath: expectedRelativePath,
            byteSize: max(0, metadata.byteSize),
            modifiedAtEpochSeconds: metadata.modifiedAtEpochSeconds
        )
    }
}
