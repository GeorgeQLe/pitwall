import Foundation

/// Presence-only metadata for a single Gemini artifact observed by the
/// Windows filesystem probe. The probe never reads file bytes — only
/// existence, byte size, and modification time (seconds since epoch) are
/// surfaced.
public struct WindowsGeminiArtifactMetadata: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int64
    public let modifiedAtEpochSeconds: Int64

    public init(relativePath: String, byteSize: Int64, modifiedAtEpochSeconds: Int64) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.modifiedAtEpochSeconds = modifiedAtEpochSeconds
    }
}

/// Sanitized evidence returned to the shell from the Windows Gemini
/// detector. Values are presence-only: no absolute paths, no token-shaped
/// substrings, no file contents. `suppressed == true` means the probe
/// could not read the Gemini root and the shell must surface the degraded
/// state rather than fabricating evidence.
public struct WindowsGeminiDetectorEvidence: Equatable, Sendable {
    public let suppressed: Bool
    public let artifacts: [String: WindowsGeminiArtifactMetadata]
    public let chatSessionCount: Int

    public init(
        suppressed: Bool,
        artifacts: [String: WindowsGeminiArtifactMetadata],
        chatSessionCount: Int
    ) {
        self.suppressed = suppressed
        self.artifacts = artifacts
        self.chatSessionCount = chatSessionCount
    }

    public var settingsDetected: Bool { artifacts["settings.json"] != nil }
    public var authDetected: Bool { artifacts["oauth_creds.json"] != nil }
}

public protocol WindowsGeminiFilesystemProbing: Sendable {
    func probe(relativePath: String) -> WindowsGeminiArtifactMetadata?
    func childCount(relativeDirectory: String) -> Int
    var isAvailable: Bool { get }
}

public struct WindowsGeminiSuppressedProbe: WindowsGeminiFilesystemProbing {
    public init() {}
    public func probe(relativePath: String) -> WindowsGeminiArtifactMetadata? { nil }
    public func childCount(relativeDirectory: String) -> Int { 0 }
    public var isAvailable: Bool { false }
}

public struct WindowsGeminiDetector: Sendable {
    public let root: WindowsStorageRoot
    private let probe: WindowsGeminiFilesystemProbing

    public init(root: WindowsStorageRoot, probe: WindowsGeminiFilesystemProbing) {
        self.root = root
        self.probe = probe
    }

    /// Resolves the default Windows Gemini root under `%APPDATA%\Gemini\`.
    /// Gemini user-level artifacts (`settings.json`, `oauth_creds.json`,
    /// `tmp/**/chats/session-*.json`) live in the roaming profile, so
    /// `%APPDATA%` is the authoritative location; `%LOCALAPPDATA%` is not
    /// used.
    public static func roamingRoot(appDataPath: String) -> WindowsStorageRoot {
        WindowsStorageRoot.roaming(
            appDataPath: appDataPath,
            applicationFolderName: "Gemini"
        )
    }

    public func detect() -> WindowsGeminiDetectorEvidence {
        guard probe.isAvailable else {
            return WindowsGeminiDetectorEvidence(
                suppressed: true,
                artifacts: [:],
                chatSessionCount: 0
            )
        }
        var artifacts: [String: WindowsGeminiArtifactMetadata] = [:]
        for name in ["settings.json", "oauth_creds.json"] {
            if let meta = probe.probe(relativePath: name) {
                artifacts[name] = WindowsGeminiSanitizer.sanitize(meta, expectedRelativePath: name)
            }
        }
        return WindowsGeminiDetectorEvidence(
            suppressed: false,
            artifacts: artifacts,
            chatSessionCount: probe.childCount(relativeDirectory: "tmp")
        )
    }
}

enum WindowsGeminiSanitizer {
    static func sanitize(
        _ metadata: WindowsGeminiArtifactMetadata,
        expectedRelativePath: String
    ) -> WindowsGeminiArtifactMetadata {
        WindowsGeminiArtifactMetadata(
            relativePath: expectedRelativePath,
            byteSize: max(0, metadata.byteSize),
            modifiedAtEpochSeconds: metadata.modifiedAtEpochSeconds
        )
    }
}
