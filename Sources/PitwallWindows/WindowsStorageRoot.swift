import Foundation

/// Resolves the root directory Pitwall writes to on Windows without hard-coding
/// `%APPDATA%` inside any adapter. Tests inject a tmp directory; production wires
/// to the real roaming profile.
public struct WindowsStorageRoot: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public static func roaming(
        appDataPath: String,
        applicationFolderName: String = PitwallWindows.defaultApplicationFolderName
    ) -> WindowsStorageRoot {
        let base = URL(fileURLWithPath: appDataPath, isDirectory: true)
        return WindowsStorageRoot(
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
}
