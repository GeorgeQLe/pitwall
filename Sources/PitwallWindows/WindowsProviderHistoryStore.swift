import Foundation
import PitwallCore
import PitwallShared

public actor WindowsProviderHistoryStore: ProviderHistoryStorage {
    public static let defaultFileName = "provider-history.v1.json"
    public static let defaultRetentionInterval: TimeInterval = 7 * 24 * 60 * 60

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
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() async -> [ProviderHistorySnapshot] {
        guard
            fileManager.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL),
            let snapshots = try? decoder.decode([ProviderHistorySnapshot].self, from: data)
        else {
            return []
        }
        return snapshots
    }

    public func save(_ snapshots: [ProviderHistorySnapshot]) async throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(snapshots)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func append(
        _ snapshot: ProviderHistorySnapshot,
        now: Date,
        maximumRetentionInterval: TimeInterval
    ) async throws {
        var snapshots = await load()
        snapshots.append(snapshot)
        let retained = ProviderHistoryRetention(
            now: now,
            maximumRetentionInterval: maximumRetentionInterval
        ).retainedSnapshots(from: snapshots)
        try await save(retained)
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
