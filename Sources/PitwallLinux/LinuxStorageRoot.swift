import Foundation

/// Resolves a root directory the Linux shell writes to without hard-coding
/// `$XDG_CONFIG_HOME` / `$XDG_DATA_HOME` inside any adapter. Tests inject a
/// tmp directory; production wires to the resolved XDG path.
public struct LinuxStorageRoot: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    /// Resolves `$XDG_CONFIG_HOME/<app>/` with a `~/.config/<app>/` fallback.
    public static func xdgConfig(
        xdgConfigHome: String?,
        home: String,
        applicationFolderName: String = PitwallLinux.defaultApplicationFolderName
    ) -> LinuxStorageRoot {
        let base = Self.resolveBase(
            override: xdgConfigHome,
            home: home,
            fallbackRelative: ".config"
        )
        return LinuxStorageRoot(
            rootDirectory: base.appendingPathComponent(applicationFolderName, isDirectory: true)
        )
    }

    /// Resolves `$XDG_DATA_HOME/<app>/` with a `~/.local/share/<app>/` fallback.
    public static func xdgData(
        xdgDataHome: String?,
        home: String,
        applicationFolderName: String = PitwallLinux.defaultApplicationFolderName
    ) -> LinuxStorageRoot {
        let base = Self.resolveBase(
            override: xdgDataHome,
            home: home,
            fallbackRelative: ".local/share"
        )
        return LinuxStorageRoot(
            rootDirectory: base.appendingPathComponent(applicationFolderName, isDirectory: true)
        )
    }

    public func fileURL(for fileName: String) -> URL {
        rootDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func ensureDirectoryExists(
        using fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private static func resolveBase(
        override: String?,
        home: String,
        fallbackRelative: String
    ) -> URL {
        if let override, !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)
        return homeURL.appendingPathComponent(fallbackRelative, isDirectory: true)
    }
}
