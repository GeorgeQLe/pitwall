import Foundation
import PitwallCore

public protocol LocalProviderSnapshotLoading {
    func loadCodexSnapshot() throws -> LocalProviderFileSnapshot
    func loadGeminiSnapshot() throws -> LocalProviderFileSnapshot
}

public struct LocalProviderSnapshotLoader: LocalProviderSnapshotLoading {
    private static let maxReadableBytes = 128 * 1_024

    private let fileManager: FileManager
    private let environment: [String: String]
    private let homeDirectory: URL

    public init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    public func loadCodexSnapshot() throws -> LocalProviderFileSnapshot {
        let root = providerRoot(
            environmentKey: "CODEX_HOME",
            defaultRelativePath: ".codex"
        )
        var files: [String: String] = [:]

        addPresence("config.toml", from: root, to: &files)
        addPresence("auth.json", from: root, to: &files)
        addPresence("history.jsonl", from: root, to: &files)
        addRecursivePresence(
            under: root.appendingPathComponent("sessions"),
            relativePrefix: "sessions",
            suffix: ".jsonl",
            to: &files
        )
        addSanitizedLogHints(
            under: root.appendingPathComponent("logs"),
            relativePrefix: "logs",
            to: &files
        )

        return LocalProviderFileSnapshot(homePath: root.path, files: files)
    }

    public func loadGeminiSnapshot() throws -> LocalProviderFileSnapshot {
        let root = providerRoot(
            environmentKey: "GEMINI_HOME",
            defaultRelativePath: ".gemini"
        )
        var files: [String: String] = [:]

        addSanitizedGeminiSettings(from: root.appendingPathComponent("settings.json"), to: &files)
        addPresence("oauth_creds.json", from: root, to: &files)
        addSanitizedGeminiChatSessions(
            under: root.appendingPathComponent("tmp"),
            relativePrefix: "tmp",
            to: &files
        )

        return LocalProviderFileSnapshot(homePath: root.path, files: files)
    }

    private func providerRoot(
        environmentKey: String,
        defaultRelativePath: String
    ) -> URL {
        if let override = environment[environmentKey], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return homeDirectory.appendingPathComponent(defaultRelativePath, isDirectory: true)
    }

    private func addPresence(
        _ relativePath: String,
        from root: URL,
        to files: inout [String: String]
    ) {
        let url = root.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        files[relativePath] = ""
    }

    private func addRecursivePresence(
        under root: URL,
        relativePrefix: String,
        suffix: String,
        to files: inout [String: String]
    ) {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == String(suffix.dropFirst()) else {
                continue
            }

            let relativePath = relativePath(for: url, root: root, prefix: relativePrefix)
            files[relativePath] = ""
        }
    }

    private func addSanitizedLogHints(
        under root: URL,
        relativePrefix: String,
        to files: inout [String: String]
    ) {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard let content = readBoundedText(url),
                  LocalProviderEvidenceProxy.containsAnyRateLimitHint(in: content) else {
                continue
            }

            let relativePath = relativePath(for: url, root: root, prefix: relativePrefix)
            files[relativePath] = "rate-limit"
        }
    }

    private func addSanitizedGeminiSettings(
        from url: URL,
        to files: inout [String: String]
    ) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        let content = readBoundedText(url).flatMap(Self.sanitizedGeminiSettingsJSON) ?? "{}"
        files["settings.json"] = content
    }

    private func addSanitizedGeminiChatSessions(
        under root: URL,
        relativePrefix: String,
        to files: inout [String: String]
    ) {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            let filename = url.lastPathComponent
            guard filename.hasPrefix("session-"),
                  url.pathExtension == "json",
                  url.path.contains("/chats/") else {
                continue
            }

            let sanitized = readBoundedText(url).flatMap(Self.sanitizedGeminiChatJSON) ?? "{}"
            let relativePath = relativePath(for: url, root: root, prefix: relativePrefix)
            files[relativePath] = sanitized
        }
    }

    private func readBoundedText(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let data = handle.readData(ofLength: Self.maxReadableBytes)
        return String(data: data, encoding: .utf8)
    }

    private func relativePath(for url: URL, root: URL, prefix: String) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let suffix = path.hasPrefix(rootPath)
            ? String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : url.lastPathComponent
        return [prefix, suffix].filter { !$0.isEmpty }.joined(separator: "/")
    }

    private static func sanitizedGeminiSettingsJSON(from content: String) -> String {
        guard
            let data = content.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "{}"
        }

        var sanitized: [String: Any] = [:]
        if let selectedAuthType = selectedGeminiAuthType(from: object) {
            sanitized["selectedAuthType"] = selectedAuthType
        }
        if let profile = object["profile"] as? String {
            sanitized["profile"] = profile
        }

        return jsonString(from: sanitized)
    }

    private static func selectedGeminiAuthType(from object: [String: Any]) -> String? {
        if let selectedAuthType = object["selectedAuthType"] as? String {
            return selectedAuthType
        }

        return ((object["security"] as? [String: Any])?["auth"] as? [String: Any])?["selectedType"] as? String
    }

    private static func sanitizedGeminiChatJSON(from content: String) -> String {
        guard
            let data = content.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "{}"
        }

        var sanitized: [String: Any] = [:]
        if let tokenCount = object["tokenCount"] {
            sanitized["tokenCount"] = tokenCount
        }
        if let model = object["model"] as? String {
            sanitized["model"] = model
        }
        if let timestamp = object["timestamp"] as? String {
            sanitized["timestamp"] = timestamp
        }

        return jsonString(from: sanitized)
    }

    private static func jsonString(from object: [String: Any]) -> String {
        guard
            JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let value = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return value
    }
}

private enum LocalProviderEvidenceProxy {
    static func containsAnyRateLimitHint(in value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("rate-limit")
            || normalized.contains("usage-limit")
            || normalized.contains("lockout")
            || normalized.contains("limit reached")
            || normalized.contains("reset at")
    }
}
