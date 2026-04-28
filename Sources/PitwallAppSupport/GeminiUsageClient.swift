import Foundation

public enum GeminiUsageClientError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedAuthMode(String?)
    case credentialsMissing
    case credentialsMalformed
    case tokenExpiredAndCannotRefresh
    case httpStatus(Int)
    case networkUnavailable
    case projectUnavailable
    case quotaUnavailable

    public var errorDescription: String? {
        switch self {
        case let .unsupportedAuthMode(mode):
            return "Gemini CLI auth mode is not supported for quota telemetry: \(mode ?? "unknown")."
        case .credentialsMissing:
            return "Gemini CLI OAuth credentials were not found."
        case .credentialsMalformed:
            return "Gemini CLI OAuth credentials could not be decoded."
        case .tokenExpiredAndCannotRefresh:
            return "Gemini CLI OAuth credentials are expired and cannot be refreshed by Pitwall."
        case let .httpStatus(statusCode):
            return "Gemini quota request returned HTTP \(statusCode)."
        case .networkUnavailable:
            return "Gemini quota request could not reach Google."
        case .projectUnavailable:
            return "Gemini Code Assist project could not be resolved."
        case .quotaUnavailable:
            return "Gemini quota response did not include usable quota buckets."
        }
    }
}

public struct GeminiQuotaBucket: Equatable, Sendable {
    public var modelId: String?
    public var tokenType: String?
    public var remainingAmount: Double?
    public var remainingFraction: Double?
    public var resetsAt: Date?

    public init(
        modelId: String? = nil,
        tokenType: String? = nil,
        remainingAmount: Double? = nil,
        remainingFraction: Double? = nil,
        resetsAt: Date? = nil
    ) {
        self.modelId = modelId
        self.tokenType = tokenType
        self.remainingAmount = remainingAmount
        self.remainingFraction = remainingFraction
        self.resetsAt = resetsAt
    }

    public var usedPercent: Double? {
        remainingFraction.map { max(0, min(100, (1 - $0) * 100)) }
    }
}

public struct GeminiUsageClientResult: Equatable, Sendable {
    public var projectId: String
    public var tier: String?
    public var buckets: [GeminiQuotaBucket]
    public var fetchedAt: Date

    public init(
        projectId: String,
        tier: String? = nil,
        buckets: [GeminiQuotaBucket],
        fetchedAt: Date
    ) {
        self.projectId = projectId
        self.tier = tier
        self.buckets = buckets
        self.fetchedAt = fetchedAt
    }

    public var primaryBucket: GeminiQuotaBucket? {
        buckets.first { $0.usedPercent != nil } ?? buckets.first
    }
}

public protocol GeminiUsageClienting: Sendable {
    func fetchUsage(now: Date) async throws -> GeminiUsageClientResult
}

public struct GeminiUsageHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol GeminiUsageHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> GeminiUsageHTTPResponse
}

public struct URLSessionGeminiUsageHTTPTransport: GeminiUsageHTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> GeminiUsageHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiUsageClientError.networkUnavailable
        }
        return GeminiUsageHTTPResponse(statusCode: httpResponse.statusCode, data: data)
    }
}

public struct GeminiUsageClient: GeminiUsageClienting, @unchecked Sendable {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let homeDirectory: URL
    private let transport: any GeminiUsageHTTPTransport
    private let codeAssistBaseURL: URL
    private let tokenURL: URL

    public init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        transport: any GeminiUsageHTTPTransport = URLSessionGeminiUsageHTTPTransport(),
        codeAssistBaseURL: URL = URL(string: "https://cloudcode-pa.googleapis.com")!,
        tokenURL: URL = URL(string: "https://oauth2.googleapis.com/token")!
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.transport = transport
        self.codeAssistBaseURL = codeAssistBaseURL
        self.tokenURL = tokenURL
    }

    public func fetchUsage(now: Date = Date()) async throws -> GeminiUsageClientResult {
        let root = geminiRoot()
        let settings = try readSettings(from: root)
        guard settings.selectedAuthType == "oauth-personal" else {
            throw GeminiUsageClientError.unsupportedAuthMode(settings.selectedAuthType)
        }

        var credentials = try readCredentials(from: root)
        let accessToken = try await validAccessToken(from: &credentials, now: now)
        let requestedProject = environment["GOOGLE_CLOUD_PROJECT_ID"] ?? environment["GOOGLE_CLOUD_PROJECT"]
        let loadResponse = try await loadCodeAssist(accessToken: accessToken, project: requestedProject)
        let project = requestedProject
            ?? loadResponse.project
            ?? settings.project
            ?? settings.profile
        guard let project, !project.isEmpty else {
            throw GeminiUsageClientError.projectUnavailable
        }

        let buckets = try await retrieveQuota(accessToken: accessToken, project: project)
        guard !buckets.isEmpty else {
            throw GeminiUsageClientError.quotaUnavailable
        }

        return GeminiUsageClientResult(
            projectId: project,
            tier: loadResponse.tier,
            buckets: buckets,
            fetchedAt: now
        )
    }

    private func geminiRoot() -> URL {
        if let override = environment["GEMINI_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(".gemini", isDirectory: true)
    }

    private func readSettings(from root: URL) throws -> GeminiSettings {
        let url = root.appendingPathComponent("settings.json")
        guard fileManager.fileExists(atPath: url.path) else {
            return GeminiSettings(selectedAuthType: nil, profile: nil, project: nil)
        }
        let data = try Data(contentsOf: url)
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return GeminiSettings(
            selectedAuthType: Self.settingsAuthType(from: object),
            profile: object?["profile"] as? String,
            project: object?["project"] as? String
        )
    }

    private func readCredentials(from root: URL) throws -> GeminiOAuthCredentials {
        let url = root.appendingPathComponent("oauth_creds.json")
        guard fileManager.fileExists(atPath: url.path) else {
            throw GeminiUsageClientError.credentialsMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(GeminiOAuthCredentials.self, from: data)
        } catch {
            throw GeminiUsageClientError.credentialsMalformed
        }
    }

    private func validAccessToken(
        from credentials: inout GeminiOAuthCredentials,
        now: Date
    ) async throws -> String {
        if let accessToken = credentials.accessToken,
           !accessToken.isEmpty,
           !credentials.isExpired(now: now) {
            return accessToken
        }

        guard
            let refreshToken = credentials.refreshToken,
            !refreshToken.isEmpty,
            let metadata = oauthClientMetadata(from: credentials)
        else {
            throw GeminiUsageClientError.tokenExpiredAndCannotRefresh
        }

        let refreshed = try await refreshAccessToken(
            refreshToken: refreshToken,
            clientId: metadata.clientId,
            clientSecret: metadata.clientSecret
        )
        credentials.accessToken = refreshed.accessToken
        return refreshed.accessToken
    }

    private func oauthClientMetadata(from credentials: GeminiOAuthCredentials) -> GeminiOAuthClientMetadata? {
        if let clientId = credentials.clientId ?? environment["GEMINI_OAUTH_CLIENT_ID"],
           let clientSecret = credentials.clientSecret ?? environment["GEMINI_OAUTH_CLIENT_SECRET"] {
            return GeminiOAuthClientMetadata(clientId: clientId, clientSecret: clientSecret)
        }

        return candidateOAuth2SourceFiles()
            .compactMap(metadataFromOAuth2SourceFile)
            .first
    }

    private func candidateOAuth2SourceFiles() -> [URL] {
        var paths: [String] = []
        if let override = environment["GEMINI_CLI_OAUTH2_PATH"], !override.isEmpty {
            paths.append(override)
        }
        paths += [
            "/opt/homebrew/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            "/usr/local/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js"
        ]
        return paths.map { URL(fileURLWithPath: $0) }
    }

    private func metadataFromOAuth2SourceFile(_ url: URL) -> GeminiOAuthClientMetadata? {
        guard
            fileManager.fileExists(atPath: url.path),
            let content = try? String(contentsOf: url, encoding: .utf8),
            let clientId = Self.javascriptStringConstant(named: "OAUTH_CLIENT_ID", in: content),
            let clientSecret = Self.javascriptStringConstant(named: "OAUTH_CLIENT_SECRET", in: content)
        else {
            return nil
        }

        return GeminiOAuthClientMetadata(clientId: clientId, clientSecret: clientSecret)
    }

    private func refreshAccessToken(
        refreshToken: String,
        clientId: String,
        clientSecret: String
    ) async throws -> GeminiOAuthRefreshResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = Self.formEncoded(body).data(using: .utf8)

        let response = try await send(request)
        do {
            return try JSONDecoder().decode(GeminiOAuthRefreshResponse.self, from: response.data)
        } catch {
            throw GeminiUsageClientError.credentialsMalformed
        }
    }

    private func loadCodeAssist(accessToken: String, project: String?) async throws -> GeminiCodeAssistLoadResponse {
        let url = codeAssistBaseURL.appendingPathComponent("v1internal:loadCodeAssist")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "metadata": [
                "ideType": "IDE_UNSPECIFIED",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI"
            ]
        ]
        if let project {
            body["cloudaicompanionProject"] = project
            body["metadata"] = [
                "ideType": "IDE_UNSPECIFIED",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI",
                "duetProject": project
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await send(request)
        let object = Self.jsonObject(from: response.data)
        return GeminiCodeAssistLoadResponse(
            project: Self.stringValue(in: object, keys: ["cloudaicompanionProject", "cloudAiCompanionProject", "project"]),
            tier: Self.stringValue(in: object, keys: ["currentTier", "tier", "userTier"])
        )
    }

    private func retrieveQuota(
        accessToken: String,
        project: String
    ) async throws -> [GeminiQuotaBucket] {
        let url = codeAssistBaseURL.appendingPathComponent("v1internal:retrieveUserQuota")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "project": project,
            "userAgent": "Pitwall/0"
        ])

        let response = try await send(request)
        return Self.quotaBuckets(from: response.data)
    }

    private func send(_ request: URLRequest) async throws -> GeminiUsageHTTPResponse {
        let response: GeminiUsageHTTPResponse
        do {
            response = try await transport.data(for: request)
        } catch let error as GeminiUsageClientError {
            throw error
        } catch {
            throw GeminiUsageClientError.networkUnavailable
        }
        guard (200...299).contains(response.statusCode) else {
            throw GeminiUsageClientError.httpStatus(response.statusCode)
        }
        return response
    }

    private static func quotaBuckets(from data: Data) -> [GeminiQuotaBucket] {
        let object = jsonObject(from: data)
        let arrays = [
            object["quotaBuckets"],
            object["buckets"],
            object["quotas"],
            object["userQuotas"]
        ]
        let bucketObjects = arrays.compactMap { $0 as? [[String: Any]] }.first ?? []

        return bucketObjects.map { bucket in
            GeminiQuotaBucket(
                modelId: stringValue(in: bucket, keys: ["modelId", "model"]),
                tokenType: stringValue(in: bucket, keys: ["tokenType", "type"]),
                remainingAmount: doubleValue(in: bucket, keys: ["remainingAmount", "remaining", "remainingTokens"]),
                remainingFraction: doubleValue(in: bucket, keys: ["remainingFraction", "remainingPercent"]).map {
                    $0 > 1 ? $0 / 100 : $0
                },
                resetsAt: dateValue(in: bucket, keys: ["resetTime", "resetsAt", "resetAt"])
            )
        }
    }

    private static func jsonObject(from data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func stringValue(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
            if let nested = object[key] as? [String: Any],
               let name = stringValue(in: nested, keys: ["name", "id", "value"]) {
                return name
            }
        }
        return nil
    }

    private static func doubleValue(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? Double {
                return value
            }
            if let value = object[key] as? Int {
                return Double(value)
            }
            if let value = object[key] as? String, let double = Double(value) {
                return double
            }
        }
        return nil
    }

    private static func dateValue(in object: [String: Any], keys: [String]) -> Date? {
        let formatter = ISO8601DateFormatter()
        for key in keys {
            if let value = object[key] as? String,
               let date = formatter.date(from: value) {
                return date
            }
            if let value = object[key] as? TimeInterval {
                return Date(timeIntervalSince1970: value)
            }
        }
        return nil
    }

    private static func formEncoded(_ values: [String: String]) -> String {
        values
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .sorted()
            .joined(separator: "&")
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private static func settingsAuthType(from object: [String: Any]?) -> String? {
        if let selectedAuthType = object?["selectedAuthType"] as? String {
            return selectedAuthType
        }

        return ((object?["security"] as? [String: Any])?["auth"] as? [String: Any])?["selectedType"] as? String
    }

    private static func javascriptStringConstant(named name: String, in content: String) -> String? {
        let pattern = #"const\s+\#(name)\s*=\s*['"]([^'"]+)['"]"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: content,
                range: NSRange(content.startIndex..., in: content)
            ),
            let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }

        return String(content[range])
    }
}

private struct GeminiSettings {
    var selectedAuthType: String?
    var profile: String?
    var project: String?
}

private struct GeminiOAuthCredentials: Decodable {
    var accessToken: String?
    var refreshToken: String?
    var expiryDate: TimeInterval?
    var expiresAt: TimeInterval?
    var clientId: String?
    var clientSecret: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiryDate = "expiry_date"
        case expiresAt = "expires_at"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }

    func isExpired(now: Date) -> Bool {
        let rawExpiry = expiryDate ?? expiresAt
        guard let rawExpiry else {
            return false
        }
        let expirySeconds = rawExpiry > 10_000_000_000 ? rawExpiry / 1000 : rawExpiry
        return Date(timeIntervalSince1970: expirySeconds).timeIntervalSince(now) < 60
    }
}

private struct GeminiOAuthRefreshResponse: Decodable {
    var accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct GeminiOAuthClientMetadata {
    var clientId: String
    var clientSecret: String
}

private struct GeminiCodeAssistLoadResponse {
    var project: String?
    var tier: String?
}
