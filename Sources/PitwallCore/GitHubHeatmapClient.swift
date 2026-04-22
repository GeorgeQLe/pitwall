import Foundation

public struct GitHubHeatmapResponseMapper: Sendable {
    public init() {}

    public func map(data: Data, maxWeeks: Int = 12) throws -> GitHubHeatmap {
        let response = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        guard let calendar = response.data?.user?.contributionsCollection.contributionCalendar else {
            throw GitHubHeatmapError.invalidResponse
        }

        let weeks = calendar.weeks.suffix(max(1, maxWeeks)).map { week in
            GitHubHeatmapWeek(
                days: week.contributionDays.map { day in
                    GitHubHeatmapDay(
                        date: day.date,
                        contributionCount: day.contributionCount,
                        color: day.color
                    )
                }
            )
        }

        return GitHubHeatmap(weeks: Array(weeks))
    }
}

public final class GitHubHeatmapTokenManager: Sendable {
    private let secretStore: ProviderSecretStore

    public init(secretStore: ProviderSecretStore) {
        self.secretStore = secretStore
    }

    public func saveToken(_ token: String, username: String) async throws -> GitHubHeatmapTokenState {
        try await secretStore.save(token, for: Self.secretKey(username: username))
        return GitHubHeatmapTokenState(username: username, status: .configured)
    }

    public func loadToken(username: String) async throws -> String? {
        try await secretStore.loadSecret(for: Self.secretKey(username: username))
    }

    public func publicState(username: String) async throws -> GitHubHeatmapTokenState {
        let status: GitHubHeatmapTokenStatus = try await loadToken(username: username) == nil ? .missing : .configured
        return GitHubHeatmapTokenState(username: username, status: status)
    }

    public func markInvalid(username: String) -> GitHubHeatmapTokenState {
        GitHubHeatmapTokenState(username: username, status: .invalidOrExpired)
    }

    public func deleteToken(username: String) async throws {
        try await secretStore.deleteSecret(for: Self.secretKey(username: username))
    }

    public static func secretKey(username: String) -> ProviderSecretKey {
        ProviderSecretKey(
            providerId: .github,
            accountId: username,
            purpose: "heatmap-token"
        )
    }
}

private struct GraphQLResponse: Decodable {
    var data: GraphQLData?
}

private struct GraphQLData: Decodable {
    var user: GraphQLUser?
}

private struct GraphQLUser: Decodable {
    var contributionsCollection: ContributionsCollection
}

private struct ContributionsCollection: Decodable {
    var contributionCalendar: ContributionCalendar
}

private struct ContributionCalendar: Decodable {
    var weeks: [ContributionWeek]
}

private struct ContributionWeek: Decodable {
    var contributionDays: [ContributionDay]
}

private struct ContributionDay: Decodable {
    var date: String
    var contributionCount: Int
    var color: String
}
