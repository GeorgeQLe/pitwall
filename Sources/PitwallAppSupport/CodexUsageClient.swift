import Foundation

public enum CodexUsageClientError: Error, Equatable, LocalizedError, Sendable {
    case appServerError(String)
    case appServerProtocol(String)
    case cliUnavailable
    case decodingFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case let .appServerError(message):
            return "Codex app-server returned an error: \(message)"
        case let .appServerProtocol(message):
            return "Codex app-server protocol error: \(message)"
        case .cliUnavailable:
            return "Codex CLI is unavailable."
        case .decodingFailed:
            return "Codex usage response could not be decoded."
        case .timeout:
            return "Codex app-server usage request timed out."
        }
    }
}

public struct CodexRateLimitWindow: Equatable, Sendable {
    public var usedPercent: Double
    public var windowDurationMinutes: Int?
    public var resetsAt: Date?

    public init(
        usedPercent: Double,
        windowDurationMinutes: Int? = nil,
        resetsAt: Date? = nil
    ) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }
}

extension CodexRateLimitWindow: Decodable {
    private enum CodingKeys: String, CodingKey {
        case usedPercent
        case windowDurationMinutes = "windowDurationMins"
        case resetsAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        windowDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .windowDurationMinutes)
        resetsAt = try container
            .decodeIfPresent(TimeInterval.self, forKey: .resetsAt)
            .map(Date.init(timeIntervalSince1970:))
    }
}

public struct CodexCreditsSnapshot: Equatable, Decodable, Sendable {
    public var hasCredits: Bool
    public var unlimited: Bool
    public var balance: String?

    public init(
        hasCredits: Bool,
        unlimited: Bool,
        balance: String? = nil
    ) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct CodexRateLimitSnapshot: Equatable, Decodable, Sendable {
    public var limitId: String?
    public var limitName: String?
    public var primary: CodexRateLimitWindow?
    public var secondary: CodexRateLimitWindow?
    public var credits: CodexCreditsSnapshot?
    public var planType: String?
    public var rateLimitReachedType: String?

    public init(
        limitId: String? = nil,
        limitName: String? = nil,
        primary: CodexRateLimitWindow? = nil,
        secondary: CodexRateLimitWindow? = nil,
        credits: CodexCreditsSnapshot? = nil,
        planType: String? = nil,
        rateLimitReachedType: String? = nil
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
        self.rateLimitReachedType = rateLimitReachedType
    }
}

public struct CodexUsageClientResult: Equatable, Sendable {
    public var rateLimits: CodexRateLimitSnapshot
    public var rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
    public var fetchedAt: Date

    public init(
        rateLimits: CodexRateLimitSnapshot,
        rateLimitsByLimitId: [String: CodexRateLimitSnapshot]? = nil,
        fetchedAt: Date
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
        self.fetchedAt = fetchedAt
    }

    public var preferredRateLimit: CodexRateLimitSnapshot {
        rateLimits
    }
}

public protocol CodexUsageClienting: Sendable {
    func fetchUsage(now: Date) async throws -> CodexUsageClientResult
}

public protocol CodexRateLimitPayloadFetching: Sendable {
    func fetchRateLimitsPayload() async throws -> Data
}

public struct CodexUsageClientParser: Sendable {
    public init() {}

    public func parse(_ data: Data, fetchedAt: Date) throws -> CodexUsageClientResult {
        do {
            let decoded = try JSONDecoder().decode(CodexUsageResponsePayload.self, from: data)
            return CodexUsageClientResult(
                rateLimits: decoded.rateLimits,
                rateLimitsByLimitId: decoded.rateLimitsByLimitId,
                fetchedAt: fetchedAt
            )
        } catch {
            throw CodexUsageClientError.decodingFailed
        }
    }
}

public struct CodexAppServerUsageClient: CodexUsageClienting {
    private let transport: any CodexRateLimitPayloadFetching
    private let parser: CodexUsageClientParser

    public init(
        transport: any CodexRateLimitPayloadFetching = ProcessCodexAppServerRateLimitTransport(),
        parser: CodexUsageClientParser = CodexUsageClientParser()
    ) {
        self.transport = transport
        self.parser = parser
    }

    public func fetchUsage(now: Date = Date()) async throws -> CodexUsageClientResult {
        let payload = try await transport.fetchRateLimitsPayload()
        return try parser.parse(payload, fetchedAt: now)
    }
}

public struct ProcessCodexAppServerRateLimitTransport: CodexRateLimitPayloadFetching {
    private let timeoutNanoseconds: UInt64

    public init(timeoutNanoseconds: UInt64 = 10_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    public func fetchRateLimitsPayload() async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server", "--listen", "stdio://"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let responseBuffer = CodexAppServerResponseBuffer()
        let stdoutReader = CodexAppServerLineReader { line in
            Task {
                await responseBuffer.receive(line: line)
            }
        }
        let stderrBuffer = CodexLockedDataBuffer()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutReader.append(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrBuffer.append(data)
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw CodexUsageClientError.cliUnavailable
        }

        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            try? stdinPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        do {
            write(
                jsonLine: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"pitwall","title":"Pitwall","version":"0"},"capabilities":{"experimentalApi":true}}}"#,
                to: stdinPipe.fileHandleForWriting
            )
            _ = try await waitForResponse(id: 1, in: responseBuffer)

            write(
                jsonLine: #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read"}"#,
                to: stdinPipe.fileHandleForWriting
            )
            return try await waitForResponse(id: 2, in: responseBuffer)
        } catch let error as CodexUsageClientError {
            await responseBuffer.failPending(with: error)
            throw error
        } catch {
            let protocolError = CodexUsageClientError.appServerProtocol(error.localizedDescription)
            await responseBuffer.failPending(with: protocolError)
            throw protocolError
        }
    }

    private func write(jsonLine: String, to handle: FileHandle) {
        handle.write(Data((jsonLine + "\n").utf8))
    }

    private func waitForResponse(
        id: Int,
        in responseBuffer: CodexAppServerResponseBuffer
    ) async throws -> Data {
        try await withTimeout {
            try await responseBuffer.wait(for: id)
        }
    }

    private func withTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw CodexUsageClientError.timeout
            }

            guard let result = try await group.next() else {
                throw CodexUsageClientError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}

private struct CodexUsageResponsePayload: Decodable {
    var rateLimits: CodexRateLimitSnapshot
    var rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
}

private actor CodexAppServerResponseBuffer {
    private var responses: [Int: Result<Data, CodexUsageClientError>] = [:]
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]

    func wait(for id: Int) async throws -> Data {
        if let response = responses.removeValue(forKey: id) {
            return try response.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[id] = continuation
        }
    }

    func receive(line: String) {
        guard let decoded = Self.decode(line: line) else {
            return
        }

        if let continuation = continuations.removeValue(forKey: decoded.id) {
            switch decoded.response {
            case let .success(data):
                continuation.resume(returning: data)
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        } else {
            responses[decoded.id] = decoded.response
        }
    }

    func failPending(with error: CodexUsageClientError) {
        for continuation in continuations.values {
            continuation.resume(throwing: error)
        }
        continuations.removeAll()
    }

    private static func decode(line: String) -> (id: Int, response: Result<Data, CodexUsageClientError>)? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? Int else {
            return nil
        }

        if let errorObject = object["error"] as? [String: Any] {
            let message = (errorObject["message"] as? String) ?? "unknown app-server error"
            return (id, .failure(.appServerError(message)))
        }

        guard let resultObject = object["result"] else {
            return nil
        }

        guard JSONSerialization.isValidJSONObject(resultObject),
              let resultData = try? JSONSerialization.data(withJSONObject: resultObject) else {
            return (id, .failure(.appServerProtocol("result was not a JSON object")))
        }

        return (id, .success(resultData))
    }
}

private final class CodexAppServerLineReader: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer[..<newlineRange.lowerBound]
            buffer.removeSubrange(...newlineRange.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        lock.unlock()

        for line in lines where !line.isEmpty {
            onLine(line)
        }
    }
}

private final class CodexLockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }
}
