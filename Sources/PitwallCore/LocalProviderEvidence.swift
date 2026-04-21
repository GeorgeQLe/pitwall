import Foundation

public struct LocalProviderFileSnapshot: Equatable, Sendable {
    public var homePath: String
    public var files: [String: String]

    public init(homePath: String, files: [String: String]) {
        self.homePath = homePath
        self.files = files
    }

    public func containsFile(_ path: String) -> Bool {
        files[path] != nil
    }

    public func containsFile(where predicate: (String) -> Bool) -> Bool {
        files.keys.contains(where: predicate)
    }

    public func firstFileContent(where predicate: (String) -> Bool) -> String? {
        files.first { predicate($0.key) }?.value
    }
}

enum LocalProviderEvidence {
    static func flag(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    static func hasAnyFile(in snapshot: LocalProviderFileSnapshot) -> Bool {
        !snapshot.files.isEmpty
    }

    static func containsAnyRateLimitHint(in value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("rate-limit")
            || normalized.contains("usage-limit")
            || normalized.contains("lockout")
            || normalized.contains("limit reached")
            || normalized.contains("reset at")
    }
}
