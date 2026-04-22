import Foundation
import PitwallCore
import PitwallShared

public actor WindowsSettingsStore: SettingsStorage {
    public static let defaultFileName = "settings.v1.json"

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        root: WindowsStorageRoot,
        fileName: String = defaultFileName,
        fileManager: FileManager = .default
    ) {
        self.fileURL = root.fileURL(for: fileName)
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadPreferences() async -> UserPreferences {
        guard
            fileManager.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL),
            let stored = try? decoder.decode(StoredWindowsUserPreferences.self, from: data)
        else {
            return UserPreferences()
        }
        return stored.preferences
    }

    public func savePreferences(_ preferences: UserPreferences) async throws {
        try ensureDirectoryExists()
        let stored = StoredWindowsUserPreferences(preferences)
        let data = try encoder.encode(stored)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func ensureDirectoryExists() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
