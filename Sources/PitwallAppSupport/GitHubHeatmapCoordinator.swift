import Foundation
import PitwallCore

public struct GitHubHeatmapHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol GitHubHeatmapTransport: Sendable {
    func data(for request: URLRequest) async throws -> GitHubHeatmapHTTPResponse
}

public struct URLSessionGitHubHeatmapTransport: GitHubHeatmapTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> GitHubHeatmapHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubHeatmapError.invalidResponse
        }

        return GitHubHeatmapHTTPResponse(
            statusCode: httpResponse.statusCode,
            data: data
        )
    }
}

public struct GitHubHeatmapRefreshResult: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case skipped
        case refreshed
        case invalidToken
    }

    public var status: Status
    public var heatmap: GitHubHeatmap?
    public var settings: GitHubHeatmapSettings

    public init(status: Status, heatmap: GitHubHeatmap?, settings: GitHubHeatmapSettings) {
        self.status = status
        self.heatmap = heatmap
        self.settings = settings
    }
}

public struct GitHubHeatmapCoordinator: Sendable {
    private let transport: any GitHubHeatmapTransport
    private let tokenManager: GitHubHeatmapTokenManager
    private let refreshPolicy: GitHubHeatmapRefreshPolicy
    private let mapper: GitHubHeatmapResponseMapper
    private let endpoint: URL
    private let now: @Sendable () -> Date

    public init(
        transport: any GitHubHeatmapTransport = URLSessionGitHubHeatmapTransport(),
        tokenManager: GitHubHeatmapTokenManager,
        refreshPolicy: GitHubHeatmapRefreshPolicy = GitHubHeatmapRefreshPolicy(),
        mapper: GitHubHeatmapResponseMapper = GitHubHeatmapResponseMapper(),
        endpoint: URL = URL(string: "https://api.github.com/graphql")!,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.tokenManager = tokenManager
        self.refreshPolicy = refreshPolicy
        self.mapper = mapper
        self.endpoint = endpoint
        self.now = now
    }

    public func refresh(
        settings: GitHubHeatmapSettings,
        trigger: GitHubHeatmapRefreshTrigger
    ) async throws -> GitHubHeatmapRefreshResult {
        let currentDate = now()
        guard settings.isEnabled, !settings.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return GitHubHeatmapRefreshResult(status: .skipped, heatmap: nil, settings: settings)
        }

        guard refreshPolicy.shouldRefresh(lastRefreshAt: settings.lastRefreshAt, now: currentDate, trigger: trigger) else {
            return GitHubHeatmapRefreshResult(status: .skipped, heatmap: nil, settings: settings)
        }

        guard let token = try await tokenManager.loadToken(username: settings.username) else {
            var updated = settings
            updated.tokenState = .missing
            return GitHubHeatmapRefreshResult(status: .skipped, heatmap: nil, settings: updated)
        }

        let request = GitHubHeatmapRequest(username: settings.username, weeks: 12, now: currentDate)
        let response = try await transport.data(for: makeURLRequest(request, token: token))
        guard (200...299).contains(response.statusCode) else {
            let error = GitHubHeatmapError.httpStatus(response.statusCode)
            if error.tokenState == .invalidOrExpired {
                var updated = settings
                updated.tokenState = .invalidOrExpired
                return GitHubHeatmapRefreshResult(status: .invalidToken, heatmap: nil, settings: updated)
            }
            throw error
        }

        let heatmap = try mapper.map(data: response.data, maxWeeks: 12)
        var updated = settings
        updated.lastRefreshAt = currentDate
        updated.tokenState = .configured
        return GitHubHeatmapRefreshResult(status: .refreshed, heatmap: heatmap, settings: updated)
    }

    public func makeURLRequest(_ heatmapRequest: GitHubHeatmapRequest, token: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(GraphQLBody(
            query: heatmapRequest.query,
            variables: heatmapRequest.encodedVariables
        ))
        return request
    }
}

private struct GraphQLBody: Encodable {
    var query: String
    var variables: [String: String]
}
