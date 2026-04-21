import Foundation

public struct ClaudeUsageHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, headers: [String: String] = [:], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

public protocol ClaudeUsageHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> ClaudeUsageHTTPResponse
}

public struct URLSessionClaudeUsageHTTPTransport: ClaudeUsageHTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> ClaudeUsageHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageClientError.networkUnavailable
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }

        return ClaudeUsageHTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            data: data
        )
    }
}

public enum ClaudeUsageClientError: Error, Equatable, Sendable {
    case invalidOrganizationId
    case httpStatus(Int)
    case networkUnavailable
    case decodingFailed

    public var reason: ClaudeUsageErrorReason {
        switch self {
        case .invalidOrganizationId:
            return .unknown("invalidOrganizationId")
        case let .httpStatus(statusCode):
            return .httpStatus(statusCode)
        case .networkUnavailable:
            return .networkUnavailable
        case .decodingFailed:
            return .decodingFailed
        }
    }
}

public struct ClaudeUsageClientResult: Equatable, Sendable {
    public var response: ClaudeUsageResponse
    public var providerState: ProviderState
    public var snapshot: ClaudeUsageSnapshot?
    public var replacementSessionKey: String?

    public init(
        response: ClaudeUsageResponse,
        providerState: ProviderState,
        snapshot: ClaudeUsageSnapshot?,
        replacementSessionKey: String? = nil
    ) {
        self.response = response
        self.providerState = providerState
        self.snapshot = snapshot
        self.replacementSessionKey = replacementSessionKey
    }
}

public struct ClaudeUsageClient: Sendable {
    private let baseURL: URL
    private let parser: ClaudeUsageParser
    private let transport: any ClaudeUsageHTTPTransport
    private let pacingCalculator: PacingCalculator

    public init(
        baseURL: URL = URL(string: "https://claude.ai")!,
        parser: ClaudeUsageParser = ClaudeUsageParser(),
        transport: any ClaudeUsageHTTPTransport = URLSessionClaudeUsageHTTPTransport(),
        pacingCalculator: PacingCalculator = PacingCalculator()
    ) {
        self.baseURL = baseURL
        self.parser = parser
        self.transport = transport
        self.pacingCalculator = pacingCalculator
    }

    public func fetchUsage(
        account: ClaudeAccountMetadata,
        sessionKey: String,
        retainedSnapshots: [UsageSnapshot] = [],
        now: Date = Date()
    ) async throws -> ClaudeUsageClientResult {
        let request = try makeRequest(account: account, sessionKey: sessionKey)
        let response: ClaudeUsageHTTPResponse
        do {
            response = try await transport.data(for: request)
        } catch let error as ClaudeUsageClientError {
            throw error
        } catch {
            throw ClaudeUsageClientError.networkUnavailable
        }

        guard (200...299).contains(response.statusCode) else {
            throw ClaudeUsageClientError.httpStatus(response.statusCode)
        }

        let usageResponse: ClaudeUsageResponse
        do {
            usageResponse = try parser.parse(response.data)
        } catch {
            throw ClaudeUsageClientError.decodingFailed
        }

        let snapshot = Self.snapshot(from: usageResponse, now: now)
        return ClaudeUsageClientResult(
            response: usageResponse,
            providerState: providerState(
                account: account,
                response: usageResponse,
                snapshot: snapshot,
                retainedSnapshots: retainedSnapshots,
                now: now
            ),
            snapshot: snapshot,
            replacementSessionKey: Self.replacementSessionKey(from: response.headers)
        )
    }

    public func makeRequest(
        account: ClaudeAccountMetadata,
        sessionKey: String
    ) throws -> URLRequest {
        guard !account.organizationId.isEmpty,
              !account.organizationId.contains("/") else {
            throw ClaudeUsageClientError.invalidOrganizationId
        }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("organizations")
            .appendingPathComponent(account.organizationId)
            .appendingPathComponent("usage")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func providerState(
        account: ClaudeAccountMetadata,
        response: ClaudeUsageResponse,
        snapshot: ClaudeUsageSnapshot?,
        retainedSnapshots: [UsageSnapshot],
        now: Date
    ) -> ProviderState {
        let weekly = response.sections.first { $0.key == "seven_day" }
        let session = response.sections.first { $0.key == "five_hour" }
        let weeklyPace = weekly.flatMap { section -> PaceEvaluation? in
            guard let resetAt = section.resetsAt else {
                return nil
            }
            return pacingCalculator.evaluateWeeklyPace(
                utilizationPercent: section.utilizationPercent,
                windowStart: resetAt.addingTimeInterval(-7 * 24 * 60 * 60),
                resetAt: resetAt,
                now: now
            )
        }
        let sessionPace = session.flatMap { section -> PaceEvaluation? in
            guard let resetAt = section.resetsAt else {
                return nil
            }
            return pacingCalculator.evaluateSessionPace(
                utilizationPercent: section.utilizationPercent,
                windowStart: resetAt.addingTimeInterval(-5 * 60 * 60),
                resetAt: resetAt,
                now: now
            )
        }
        let dailyBudget = weekly.flatMap { section -> DailyBudget? in
            guard let resetAt = section.resetsAt else {
                return nil
            }
            return pacingCalculator.dailyBudget(
                weeklyUtilizationPercent: section.utilizationPercent,
                resetAt: resetAt,
                now: now,
                retainedSnapshots: retainedSnapshots
            )
        }

        return ProviderState(
            providerId: .claude,
            displayName: "Claude",
            status: .configured,
            confidence: .exact,
            headline: "Claude usage refreshed",
            primaryValue: weekly.map { "\(Self.formatPercent($0.utilizationPercent)) used" },
            secondaryValue: account.label,
            resetWindow: ResetWindow(resetsAt: weekly?.resetsAt ?? session?.resetsAt),
            lastUpdatedAt: now,
            pacingState: PacingState(
                weeklyUtilizationPercent: weekly?.utilizationPercent,
                remainingWindowDuration: weekly?.resetsAt.map { max(0, $0.timeIntervalSince(now)) },
                dailyBudget: dailyBudget,
                todayUsage: dailyBudget?.todayUsage,
                estimatedExtraUsageExposure: response.extraUsage?.usedCredits,
                weeklyPace: weeklyPace,
                sessionPace: sessionPace
            ),
            confidenceExplanation: "Claude returned fresh usage data for the selected account.",
            actions: [
                ProviderAction(kind: .refresh, title: "Refresh now"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: [
                usageRowsPayload(from: response),
                accountPayload(account: account, response: response)
            ].compactMap { $0 }
        )
    }

    private func usageRowsPayload(from response: ClaudeUsageResponse) -> ProviderSpecificPayload? {
        var values: [String: String] = [:]
        for section in response.sections {
            values[section.label] = [
                String(section.utilizationPercent),
                section.resetsAt.map(Self.formatDate) ?? "Unknown reset",
                "exact"
            ].joined(separator: "|")
        }

        if let extraUsage = response.extraUsage {
            values[extraUsage.label] = [
                String(extraUsage.utilizationPercent),
                "Monthly extra usage",
                extraUsage.isEnabled ? "enabled" : "disabled"
            ].joined(separator: "|")
        }

        guard !values.isEmpty else {
            return nil
        }
        return ProviderSpecificPayload(source: "usageRows", values: values)
    }

    private func accountPayload(
        account: ClaudeAccountMetadata,
        response: ClaudeUsageResponse
    ) -> ProviderSpecificPayload {
        var values = [
            "accountId": account.id,
            "accountLabel": account.label,
            "organizationId": account.organizationId
        ]
        if !response.unknownSectionKeys.isEmpty {
            values["unknownSectionKeys"] = response.unknownSectionKeys.sorted().joined(separator: ",")
        }
        return ProviderSpecificPayload(source: "claude", values: values)
    }

    private static func snapshot(
        from response: ClaudeUsageResponse,
        now: Date
    ) -> ClaudeUsageSnapshot? {
        guard let weekly = response.sections.first(where: { $0.key == "seven_day" }) else {
            return nil
        }

        return ClaudeUsageSnapshot(
            recordedAt: now,
            weeklyUtilizationPercent: weekly.utilizationPercent,
            weeklyResetAt: weekly.resetsAt
        )
    }

    private static func replacementSessionKey(from headers: [String: String]) -> String? {
        for (name, value) in headers where name.caseInsensitiveCompare("Set-Cookie") == .orderedSame {
            let cookies = value.split(separator: ",")
            for cookie in cookies {
                let parts = cookie.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
                guard let first = parts.first else {
                    continue
                }
                let nameValue = first.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if nameValue.count == 2,
                   nameValue[0].trimmingCharacters(in: .whitespacesAndNewlines) == "sessionKey" {
                    return String(nameValue[1])
                }
            }
        }
        return nil
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", value)
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter.pitwallClaudeClient.string(from: date)
    }
}

private extension ISO8601DateFormatter {
    static let pitwallClaudeClient: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
