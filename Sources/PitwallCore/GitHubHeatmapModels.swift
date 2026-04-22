import Foundation

public extension ProviderID {
    static let github = ProviderID(rawValue: "github")
}

public struct GitHubHeatmapRequest {
    public var query: String
    public var encodedVariables: [String: String]

    public var variables: [String: Any] {
        encodedVariables
    }

    public init(username: String, weeks: Int = 12, now: Date, calendar: Calendar = .pitwallGitHubHeatmapUTC) {
        let sanitizedWeeks = max(1, weeks)
        let toDate = calendar.startOfDay(for: now)
        let fromDate = calendar.date(byAdding: .day, value: -(sanitizedWeeks * 7), to: toDate) ?? toDate

        query = """
        query PitwallGitHubHeatmap($userName: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $userName) {
            contributionsCollection(from: $from, to: $to) {
              contributionCalendar {
                weeks {
                  contributionDays {
                    date
                    contributionCount
                    color
                  }
                }
              }
            }
          }
        }
        """
        encodedVariables = [
            "userName": username,
            "from": Self.dateString(fromDate),
            "to": Self.dateString(toDate)
        ]
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .pitwallGitHubHeatmapUTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct GitHubHeatmap: Equatable, Sendable {
    public var weeks: [GitHubHeatmapWeek]

    public init(weeks: [GitHubHeatmapWeek]) {
        self.weeks = weeks
    }
}

public struct GitHubHeatmapWeek: Equatable, Sendable {
    public var days: [GitHubHeatmapDay]

    public init(days: [GitHubHeatmapDay]) {
        self.days = days
    }
}

public struct GitHubHeatmapDay: Equatable, Sendable {
    public var date: String
    public var contributionCount: Int
    public var color: String

    public init(date: String, contributionCount: Int, color: String) {
        self.date = date
        self.contributionCount = contributionCount
        self.color = color
    }
}

public enum GitHubHeatmapRefreshTrigger: Equatable, Sendable {
    case automatic
    case manual
}

public struct GitHubHeatmapRefreshPolicy: Equatable, Sendable {
    public var minimumAutomaticRefreshInterval: TimeInterval

    public init(minimumAutomaticRefreshInterval: TimeInterval = 60 * 60) {
        self.minimumAutomaticRefreshInterval = minimumAutomaticRefreshInterval
    }

    public func shouldRefresh(lastRefreshAt: Date?, now: Date, trigger: GitHubHeatmapRefreshTrigger) -> Bool {
        guard trigger == .automatic else {
            return true
        }

        guard let lastRefreshAt else {
            return true
        }

        return now.timeIntervalSince(lastRefreshAt) >= minimumAutomaticRefreshInterval
    }
}

public enum GitHubHeatmapTokenStatus: String, Equatable, Codable, Sendable {
    case missing
    case configured
    case invalidOrExpired
}

public enum GitHubHeatmapError: Error, Equatable, Sendable {
    case httpStatus(Int)
    case invalidResponse

    public var tokenState: GitHubHeatmapTokenStatus? {
        switch self {
        case .httpStatus(401), .httpStatus(403):
            return .invalidOrExpired
        case .httpStatus, .invalidResponse:
            return nil
        }
    }
}

public struct GitHubHeatmapTokenState: Equatable, CustomStringConvertible, Sendable {
    public var username: String
    public var status: GitHubHeatmapTokenStatus

    public var renderedToken: String? {
        nil
    }

    public var description: String {
        "GitHubHeatmapTokenState(username: \(username), status: \(status.rawValue))"
    }

    public init(username: String, status: GitHubHeatmapTokenStatus) {
        self.username = username
        self.status = status
    }
}

public extension Calendar {
    static var pitwallGitHubHeatmapUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
