import Foundation

/// Presence-only metadata for a single Gemini artifact observed by the
/// Linux filesystem probe. The probe never reads file bytes — only
/// existence, byte size, and modification time (seconds since epoch) are
/// surfaced.
public struct LinuxGeminiArtifactMetadata: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int64
    public let modifiedAtEpochSeconds: Int64

    public init(relativePath: String, byteSize: Int64, modifiedAtEpochSeconds: Int64) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.modifiedAtEpochSeconds = modifiedAtEpochSeconds
    }
}

/// Sanitized evidence returned to the shell from the Linux Gemini
/// detector. Values are presence-only: no absolute paths, no token-shaped
/// substrings, no file contents. `suppressed == true` means the probe
/// could not read the Gemini root and the shell must surface the degraded
/// state rather than fabricating evidence.
public struct LinuxGeminiDetectorEvidence: Equatable, Sendable {
    public let suppressed: Bool
    public let artifacts: [String: LinuxGeminiArtifactMetadata]
    public let chatSessionCount: Int

    public init(
        suppressed: Bool,
        artifacts: [String: LinuxGeminiArtifactMetadata],
        chatSessionCount: Int
    ) {
        self.suppressed = suppressed
        self.artifacts = artifacts
        self.chatSessionCount = chatSessionCount
    }

    public var settingsDetected: Bool { artifacts["settings.json"] != nil }
    public var authDetected: Bool { artifacts["oauth_creds.json"] != nil }
}

public protocol LinuxGeminiFilesystemProbing: Sendable {
    func probe(relativePath: String) -> LinuxGeminiArtifactMetadata?
    func childCount(relativeDirectory: String) -> Int
    var isAvailable: Bool { get }
}

public struct LinuxGeminiSuppressedProbe: LinuxGeminiFilesystemProbing {
    public init() {}
    public func probe(relativePath: String) -> LinuxGeminiArtifactMetadata? { nil }
    public func childCount(relativeDirectory: String) -> Int { 0 }
    public var isAvailable: Bool { false }
}

public struct LinuxGeminiDetector: Sendable {
    public let root: LinuxStorageRoot
    private let probe: LinuxGeminiFilesystemProbing

    public init(root: LinuxStorageRoot, probe: LinuxGeminiFilesystemProbing) {
        self.root = root
        self.probe = probe
    }

    /// Resolves the default Gemini root under `$XDG_CONFIG_HOME/gemini/`
    /// with a `~/.config/gemini/` fallback, honoring XDG env overrides
    /// only at the shell boundary. `$XDG_DATA_HOME` is not used because
    /// all Gemini user-level artifacts (`settings.json`,
    /// `oauth_creds.json`, `tmp/**/chats/session-*.json`) live under
    /// `$XDG_CONFIG_HOME`.
    public static func xdgConfigRoot(xdgConfigHome: String?, home: String) -> LinuxStorageRoot {
        LinuxStorageRoot.xdgConfig(
            xdgConfigHome: xdgConfigHome,
            home: home,
            applicationFolderName: "gemini"
        )
    }

    public func detect() -> LinuxGeminiDetectorEvidence {
        guard probe.isAvailable else {
            return LinuxGeminiDetectorEvidence(
                suppressed: true,
                artifacts: [:],
                chatSessionCount: 0
            )
        }
        var artifacts: [String: LinuxGeminiArtifactMetadata] = [:]
        for name in ["settings.json", "oauth_creds.json"] {
            if let meta = probe.probe(relativePath: name) {
                artifacts[name] = LinuxGeminiSanitizer.sanitize(meta, expectedRelativePath: name)
            }
        }
        return LinuxGeminiDetectorEvidence(
            suppressed: false,
            artifacts: artifacts,
            chatSessionCount: probe.childCount(relativeDirectory: "tmp")
        )
    }
}

enum LinuxGeminiSanitizer {
    static func sanitize(
        _ metadata: LinuxGeminiArtifactMetadata,
        expectedRelativePath: String
    ) -> LinuxGeminiArtifactMetadata {
        LinuxGeminiArtifactMetadata(
            relativePath: expectedRelativePath,
            byteSize: max(0, metadata.byteSize),
            modifiedAtEpochSeconds: metadata.modifiedAtEpochSeconds
        )
    }
}
