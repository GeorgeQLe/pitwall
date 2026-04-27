import Foundation
import PitwallCore

public enum CodexAuthMode: String, CaseIterable, Equatable, Sendable {
    case chatgpt
    case apiKey

    public var displayName: String {
        switch self {
        case .chatgpt:
            return "ChatGPT"
        case .apiKey:
            return "API key"
        }
    }
}

public enum CodexSetupStatus: String, Equatable, Sendable {
    case configured
    case missing
    case unavailable
}

public struct CodexSetupState: Equatable, Sendable {
    public var status: CodexSetupStatus
    public var authMode: CodexAuthMode?
    public var headline: String
    public var detail: String

    public init(
        status: CodexSetupStatus,
        authMode: CodexAuthMode? = nil,
        headline: String,
        detail: String
    ) {
        self.status = status
        self.authMode = authMode
        self.headline = headline
        self.detail = detail
    }
}

public enum CodexDeviceAuthPhase: String, Equatable, Sendable {
    case idle
    case starting
    case awaitingBrowser
    case waitingForConfirmation
    case completing
    case succeeded
    case cancelled
    case failed
}

public enum CodexDeviceAuthFailureReason: String, Equatable, Sendable {
    case cliUnavailable
    case browserOpenFailed
    case startupParseTimeout
    case deviceFlowTimedOut
    case loginRejected
    case unexpectedOutput
    case processFailed
    case cancelledByUser
}

public struct CodexDeviceAuthSessionState: Equatable, Sendable {
    public var phase: CodexDeviceAuthPhase
    public var deviceCode: String?
    public var verificationURL: String?
    public var message: String
    public var canCancel: Bool
    public var didOpenBrowser: Bool
    public var failureReason: CodexDeviceAuthFailureReason?
    public var finalSetupState: CodexSetupState?

    public init(
        phase: CodexDeviceAuthPhase,
        deviceCode: String? = nil,
        verificationURL: String? = nil,
        message: String,
        canCancel: Bool = false,
        didOpenBrowser: Bool = false,
        failureReason: CodexDeviceAuthFailureReason? = nil,
        finalSetupState: CodexSetupState? = nil
    ) {
        self.phase = phase
        self.deviceCode = deviceCode
        self.verificationURL = verificationURL
        self.message = message
        self.canCancel = canCancel
        self.didOpenBrowser = didOpenBrowser
        self.failureReason = failureReason
        self.finalSetupState = finalSetupState
    }

    public static let idle = CodexDeviceAuthSessionState(
        phase: .idle,
        message: "Start ChatGPT sign-in to connect Codex."
    )

    public var isActive: Bool {
        switch phase {
        case .starting, .awaitingBrowser, .waitingForConfirmation, .completing:
            return true
        case .idle, .succeeded, .cancelled, .failed:
            return false
        }
    }
}

public protocol CodexAuthStatusProviding: Sendable {
    func status() async -> CodexSetupState
}

public protocol CodexAuthControlling: CodexAuthStatusProviding {
    func startChatGPTLogin() async -> CodexDeviceAuthSessionState
    func currentChatGPTLoginState() async -> CodexDeviceAuthSessionState
    func retryOpenChatGPTLoginBrowser() async -> CodexDeviceAuthSessionState
    func cancelChatGPTLogin() async -> CodexDeviceAuthSessionState
    func loginWithAPIKey(_ apiKey: String) async throws -> CodexSetupState
    func logout() async throws -> CodexSetupState
}

public struct ProcessExecutionResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32

    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }

    public var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var sanitizedCombinedOutput: String {
        Self.sanitizeTerminalOutput(combinedOutput)
    }

    static func sanitizeTerminalOutput(_ text: String) -> String {
        var sanitized = stripTerminalEscapeSequences(from: text)
        sanitized = applyBackspaces(in: sanitized)
        sanitized = sanitized.unicodeScalars
            .filter { scalar in
                if scalar == "\n" || scalar == "\r" || scalar == "\t" {
                    return true
                }
                return !CharacterSet.controlCharacters.contains(scalar)
            }
            .map(Character.init)
            .reduce(into: "") { $0.append($1) }
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTerminalEscapeSequences(from text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            guard character == "\u{001B}" else {
                result.append(character)
                index = text.index(after: index)
                continue
            }

            let nextIndex = text.index(after: index)
            guard nextIndex < text.endIndex else { break }

            switch text[nextIndex] {
            case "[":
                index = text.index(after: nextIndex)
                while index < text.endIndex {
                    let scalar = text[index].unicodeScalars.first?.value ?? 0
                    index = text.index(after: index)
                    if (0x40...0x7E).contains(scalar) {
                        break
                    }
                }
            case "]":
                index = text.index(after: nextIndex)
                while index < text.endIndex {
                    let current = text[index]
                    if current == "\u{0007}" {
                        index = text.index(after: index)
                        break
                    }
                    if current == "\u{001B}" {
                        let afterEscape = text.index(after: index)
                        if afterEscape < text.endIndex, text[afterEscape] == "\\" {
                            index = text.index(after: afterEscape)
                            break
                        }
                    }
                    index = text.index(after: index)
                }
            default:
                index = text.index(after: nextIndex)
            }
        }

        return result
    }

    private static func applyBackspaces(in text: String) -> String {
        var result: [Character] = []
        for character in text {
            if character == "\u{0008}" {
                if !result.isEmpty {
                    result.removeLast()
                }
            } else {
                result.append(character)
            }
        }
        return String(result)
    }
}

public protocol CodexCommandRunning: Sendable {
    func run(arguments: [String], stdin: Data?) async throws -> ProcessExecutionResult
}

public enum CodexDeviceAuthStreamEvent: Equatable, Sendable {
    case stdout(String)
    case stderr(String)
}

public protocol CodexDeviceAuthFlowRunning: Sendable {
    func runDeviceAuth(
        onEvent: @escaping @Sendable (CodexDeviceAuthStreamEvent) async -> Void
    ) async throws -> ProcessExecutionResult
    func cancel() async
}

public protocol BrowserOpening: Sendable {
    func open(url: URL) async throws
}

public enum CodexAuthControllerError: LocalizedError {
    case apiKeyMissing

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Enter an OpenAI API key."
        }
    }
}

public actor CodexAuthController: CodexAuthControlling {
    private let commandRunner: any CodexCommandRunning
    private let deviceAuthRunner: any CodexDeviceAuthFlowRunning
    private let browserOpener: any BrowserOpening
    private let parseTimeoutNanoseconds: UInt64
    private let sessionTimeoutNanoseconds: UInt64
    private var chatGPTLoginState = CodexDeviceAuthSessionState.idle
    private var sessionID = UUID()
    private var deviceAuthTask: Task<Void, Never>?
    private var cancelRequested = false
    private var parseTimedOut = false
    private var sessionTimedOut = false
    private var browserOpenAttempted = false
    private var observedDeviceAuthOutput = ""

    public init(
        commandRunner: any CodexCommandRunning = ProcessCodexCommandRunner(),
        deviceAuthRunner: any CodexDeviceAuthFlowRunning = ProcessCodexDeviceAuthFlowRunner(),
        browserOpener: any BrowserOpening = ShellBrowserOpener(),
        parseTimeoutNanoseconds: UInt64 = 15_000_000_000,
        sessionTimeoutNanoseconds: UInt64 = 300_000_000_000
    ) {
        self.commandRunner = commandRunner
        self.deviceAuthRunner = deviceAuthRunner
        self.browserOpener = browserOpener
        self.parseTimeoutNanoseconds = parseTimeoutNanoseconds
        self.sessionTimeoutNanoseconds = sessionTimeoutNanoseconds
    }

    public func status() async -> CodexSetupState {
        do {
            let result = try await commandRunner.run(arguments: ["login", "status"], stdin: nil)
            return Self.parseStatus(result)
        } catch {
            return CodexSetupState(
                status: .unavailable,
                headline: "Codex CLI unavailable",
                detail: "Install the Codex CLI to connect ChatGPT or API-key auth from Pitwall."
            )
        }
    }

    public func startChatGPTLogin() async -> CodexDeviceAuthSessionState {
        if chatGPTLoginState.isActive {
            return chatGPTLoginState
        }

        await deviceAuthRunner.cancel()
        deviceAuthTask?.cancel()
        sessionID = UUID()
        cancelRequested = false
        parseTimedOut = false
        sessionTimedOut = false
        browserOpenAttempted = false
        observedDeviceAuthOutput = ""
        chatGPTLoginState = CodexDeviceAuthSessionState(
            phase: .starting,
            message: "Starting Codex sign-in…",
            canCancel: true
        )

        let currentSessionID = sessionID
        deviceAuthTask = Task { [weak self] in
            await self?.runDeviceAuthSession(sessionID: currentSessionID)
        }
        return chatGPTLoginState
    }

    public func currentChatGPTLoginState() async -> CodexDeviceAuthSessionState {
        chatGPTLoginState
    }

    public func retryOpenChatGPTLoginBrowser() async -> CodexDeviceAuthSessionState {
        guard
            let verificationURL = chatGPTLoginState.verificationURL,
            let url = URL(string: verificationURL)
        else {
            return chatGPTLoginState
        }

        do {
            try await browserOpener.open(url: url)
            chatGPTLoginState.didOpenBrowser = true
            if chatGPTLoginState.isActive {
                chatGPTLoginState.phase = .waitingForConfirmation
                chatGPTLoginState.message = chatGPTLoginState.deviceCode.map {
                    "Browser opened. Finish sign-in with code \($0), then wait for Codex to confirm."
                } ?? "Browser opened. Finish sign-in, then wait for Codex to confirm."
            }
        } catch {
            chatGPTLoginState.didOpenBrowser = false
            chatGPTLoginState.phase = .awaitingBrowser
            chatGPTLoginState.failureReason = .browserOpenFailed
            chatGPTLoginState.message = "Pitwall found the sign-in link but could not open your browser. Retry opening it or use the URL below."
        }

        return chatGPTLoginState
    }

    public func cancelChatGPTLogin() async -> CodexDeviceAuthSessionState {
        guard chatGPTLoginState.isActive else {
            if chatGPTLoginState.phase == .idle {
                return chatGPTLoginState
            }
            return chatGPTLoginState
        }

        cancelRequested = true
        chatGPTLoginState = finalizedState(
            phase: .cancelled,
            message: "Codex sign-in cancelled.",
            failureReason: .cancelledByUser
        )
        await deviceAuthRunner.cancel()
        return chatGPTLoginState
    }

    public func loginWithAPIKey(_ apiKey: String) async throws -> CodexSetupState {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CodexAuthControllerError.apiKeyMissing
        }

        let stdin = Data((trimmed + "\n").utf8)
        let result = try await commandRunner.run(
            arguments: ["login", "--with-api-key"],
            stdin: stdin
        )
        let parsed = Self.parseStatus(result)
        if parsed.status == .configured {
            return parsed
        }

        let output = result.combinedOutput
        if !output.isEmpty {
            return CodexSetupState(
                status: .missing,
                headline: "Codex login failed",
                detail: output
            )
        }

        return CodexSetupState(
            status: .missing,
            headline: "Codex login failed",
            detail: "Codex did not confirm that API-key login completed."
        )
    }

    public func logout() async throws -> CodexSetupState {
        _ = try await commandRunner.run(arguments: ["logout"], stdin: nil)
        return await status()
    }

    private func runDeviceAuthSession(sessionID: UUID) async {
        let parseTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.parseTimeoutNanoseconds ?? 0)
            await self?.handleParseTimeout(sessionID: sessionID)
        }
        let sessionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.sessionTimeoutNanoseconds ?? 0)
            await self?.handleSessionTimeout(sessionID: sessionID)
        }

        do {
            let result = try await deviceAuthRunner.runDeviceAuth { [weak self] event in
                await self?.consumeDeviceAuthEvent(event, sessionID: sessionID)
            }

            parseTimeoutTask.cancel()
            sessionTimeoutTask.cancel()
            await finishDeviceAuthSession(result: result, sessionID: sessionID)
        } catch {
            parseTimeoutTask.cancel()
            sessionTimeoutTask.cancel()
            await failDeviceAuthSession(
                sessionID: sessionID,
                reason: .cliUnavailable,
                message: "Codex CLI is unavailable. Install the CLI, then try again."
            )
        }
    }

    private func consumeDeviceAuthEvent(
        _ event: CodexDeviceAuthStreamEvent,
        sessionID: UUID
    ) async {
        guard sessionID == self.sessionID, chatGPTLoginState.isActive else {
            return
        }

        let text: String
        switch event {
        case let .stdout(chunk), let .stderr(chunk):
            text = chunk
        }

        observedDeviceAuthOutput += text
        let outputToParse = ProcessExecutionResult.sanitizeTerminalOutput(observedDeviceAuthOutput)

        if chatGPTLoginState.verificationURL == nil,
           let url = Self.extractVerificationURL(from: outputToParse) {
            chatGPTLoginState.verificationURL = url
        }

        if chatGPTLoginState.deviceCode == nil,
           let code = Self.extractDeviceCode(from: outputToParse) {
            chatGPTLoginState.deviceCode = code
        }

        if chatGPTLoginState.verificationURL != nil || chatGPTLoginState.deviceCode != nil {
            let codeMessage = chatGPTLoginState.deviceCode.map { "Use code \($0) to finish sign-in." }
                ?? "Waiting for the one-time code."
            chatGPTLoginState.phase = .awaitingBrowser
            chatGPTLoginState.canCancel = true
            chatGPTLoginState.message = chatGPTLoginState.didOpenBrowser
                ? "Browser opened. \(codeMessage)"
                : "Codex sign-in is ready. \(codeMessage)"
        }

        if chatGPTLoginState.verificationURL != nil,
           chatGPTLoginState.deviceCode != nil,
           !browserOpenAttempted {
            browserOpenAttempted = true
            _ = await retryOpenChatGPTLoginBrowser()
        }
    }

    private func handleParseTimeout(sessionID: UUID) async {
        guard
            sessionID == self.sessionID,
            chatGPTLoginState.isActive,
            chatGPTLoginState.verificationURL == nil || chatGPTLoginState.deviceCode == nil
        else {
            return
        }

        parseTimedOut = true
        await deviceAuthRunner.cancel()
        await failDeviceAuthSession(
            sessionID: sessionID,
            reason: .startupParseTimeout,
            message: "Codex CLI did not print sign-in instructions in time. Try again or update the CLI if its output format changed."
        )
    }

    private func handleSessionTimeout(sessionID: UUID) async {
        guard sessionID == self.sessionID, chatGPTLoginState.isActive else {
            return
        }

        sessionTimedOut = true
        await deviceAuthRunner.cancel()
        await failDeviceAuthSession(
            sessionID: sessionID,
            reason: .deviceFlowTimedOut,
            message: "Codex sign-in timed out before the CLI confirmed login."
        )
    }

    private func finishDeviceAuthSession(
        result: ProcessExecutionResult,
        sessionID: UUID
    ) async {
        guard sessionID == self.sessionID else {
            return
        }

        if cancelRequested {
            chatGPTLoginState = finalizedState(
                phase: .cancelled,
                message: "Codex sign-in cancelled.",
                failureReason: .cancelledByUser
            )
            return
        }

        if parseTimedOut || sessionTimedOut || !chatGPTLoginState.isActive {
            return
        }

        chatGPTLoginState.phase = .completing
        chatGPTLoginState.message = "Codex is verifying your login…"
        chatGPTLoginState.canCancel = false

        let refreshedStatus = await status()
        if refreshedStatus.status == .configured {
            chatGPTLoginState = CodexDeviceAuthSessionState(
                phase: .succeeded,
                message: refreshedStatus.headline,
                didOpenBrowser: chatGPTLoginState.didOpenBrowser,
                finalSetupState: refreshedStatus
            )
            return
        }

        let failure = Self.classifyFailure(result)
        chatGPTLoginState = finalizedState(
            phase: failure == .cancelledByUser ? .cancelled : .failed,
            message: Self.message(for: failure),
            failureReason: failure
        )
    }

    private func failDeviceAuthSession(
        sessionID: UUID,
        reason: CodexDeviceAuthFailureReason,
        message: String
    ) async {
        guard sessionID == self.sessionID else {
            return
        }

        chatGPTLoginState = finalizedState(
            phase: reason == .cancelledByUser ? .cancelled : .failed,
            message: message,
            failureReason: reason
        )
    }

    private func finalizedState(
        phase: CodexDeviceAuthPhase,
        message: String,
        failureReason: CodexDeviceAuthFailureReason? = nil
    ) -> CodexDeviceAuthSessionState {
        CodexDeviceAuthSessionState(
            phase: phase,
            message: message,
            didOpenBrowser: chatGPTLoginState.didOpenBrowser,
            failureReason: failureReason
        )
    }

    private static func message(for reason: CodexDeviceAuthFailureReason) -> String {
        switch reason {
        case .cliUnavailable:
            return "Codex CLI is unavailable. Install the CLI, then try again."
        case .browserOpenFailed:
            return "Pitwall found the sign-in link but could not open your browser."
        case .startupParseTimeout:
            return "Codex CLI did not print sign-in instructions in time."
        case .deviceFlowTimedOut:
            return "Codex sign-in timed out before the CLI confirmed login."
        case .loginRejected:
            return "Codex sign-in was rejected or cancelled."
        case .unexpectedOutput:
            return "Codex CLI finished without a usable sign-in result."
        case .processFailed:
            return "Codex CLI ended before confirming login."
        case .cancelledByUser:
            return "Codex sign-in cancelled."
        }
    }

    private static func classifyFailure(_ result: ProcessExecutionResult) -> CodexDeviceAuthFailureReason {
        let normalized = result.sanitizedCombinedOutput.lowercased()
        if normalized.contains("cancelled")
            || normalized.contains("canceled")
            || normalized.contains("rejected")
            || normalized.contains("denied")
            || normalized.contains("declined")
            || normalized.contains("expired") {
            return .loginRejected
        }
        if result.exitCode != 0 {
            return .processFailed
        }
        return .unexpectedOutput
    }

    private static func extractVerificationURL(from output: String) -> String? {
        firstMatch(
            in: output,
            pattern: #"https?://[^\s"']+"#
        )
    }

    private static func extractDeviceCode(from output: String) -> String? {
        let patterns = [
            #"(?:code|device code|one-time code)[^A-Z0-9]*([A-Z0-9]{4}(?:-[A-Z0-9]{4})+)"#,
            #"(?:code|device code|one-time code)[^A-Z0-9]*([A-Z0-9]{6,})"#,
            #"\b([A-Z0-9]{4}(?:-[A-Z0-9]{4})+)\b"#
        ]

        for pattern in patterns {
            if let code = firstMatch(in: output, pattern: pattern, captureGroup: 1) ?? firstMatch(in: output, pattern: pattern) {
                return code
            }
        }

        return nil
    }

    private static func firstMatch(
        in text: String,
        pattern: String,
        captureGroup: Int = 0
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        let targetRange = match.range(at: captureGroup)
        guard let stringRange = Range(targetRange, in: text) else {
            return nil
        }
        return String(text[stringRange])
    }

    public static func parseStatus(_ result: ProcessExecutionResult) -> CodexSetupState {
        let output = result.sanitizedCombinedOutput
        let normalized = output.lowercased()

        if normalized.contains("logged in using chatgpt") {
            return CodexSetupState(
                status: .configured,
                authMode: .chatgpt,
                headline: "Connected with ChatGPT",
                detail: output.isEmpty ? "Codex CLI login is configured." : output
            )
        }

        if normalized.contains("logged in using api key")
            || normalized.contains("logged in with api key")
            || normalized.contains("api key") && normalized.contains("logged in") {
            return CodexSetupState(
                status: .configured,
                authMode: .apiKey,
                headline: "Connected with API key",
                detail: output.isEmpty ? "Codex CLI login is configured." : output
            )
        }

        if normalized.contains("not logged in")
            || normalized.contains("logged out")
            || normalized.contains("no stored authentication")
            || normalized.contains("not authenticated") {
            return CodexSetupState(
                status: .missing,
                headline: "Codex login not detected",
                detail: output.isEmpty
                    ? "Use ChatGPT or an API key to connect Codex."
                    : output
            )
        }

        if result.exitCode == 0 && normalized.contains("logged in") {
            return CodexSetupState(
                status: .configured,
                headline: "Connected",
                detail: output.isEmpty ? "Codex CLI login is configured." : output
            )
        }

        if result.exitCode != 0 {
            return CodexSetupState(
                status: .unavailable,
                headline: "Codex CLI unavailable",
                detail: output.isEmpty
                    ? "Pitwall could not read Codex CLI login status."
                    : output
            )
        }

        return CodexSetupState(
            status: .missing,
            headline: "Codex login not detected",
            detail: output.isEmpty
                ? "Use ChatGPT or an API key to connect Codex."
                : output
        )
    }
}

public struct ProcessCodexCommandRunner: CodexCommandRunning {
    public init() {}

    public func run(arguments: [String], stdin: Data?) async throws -> ProcessExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex"] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = ProcessExecutionResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: result)
            }

            do {
                if let stdin {
                    let stdinPipe = Pipe()
                    process.standardInput = stdinPipe
                    try process.run()
                    stdinPipe.fileHandleForWriting.write(stdin)
                    try stdinPipe.fileHandleForWriting.close()
                } else {
                    try process.run()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

public actor ProcessCodexDeviceAuthFlowRunner: CodexDeviceAuthFlowRunning {
    private var process: Process?

    public init() {}

    public func runDeviceAuth(
        onEvent: @escaping @Sendable (CodexDeviceAuthStreamEvent) async -> Void
    ) async throws -> ProcessExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = [
            "-q",
            "/dev/null",
            "/usr/bin/env",
            "codex",
            "login",
            "--device-auth"
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = LockedDataBuffer()
        let stderrBuffer = LockedDataBuffer()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        self.process = process

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutBuffer.append(data)
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                Task {
                    await onEvent(.stdout(string))
                }
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrBuffer.append(data)
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                Task {
                    await onEvent(.stderr(string))
                }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { [weak self] process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let stdoutData = stdoutBuffer.snapshot() + stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrBuffer.snapshot() + stderrPipe.fileHandleForReading.readDataToEndOfFile()
                Task {
                    await self?.clear(process: process)
                }
                continuation.resume(returning: ProcessExecutionResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                ))
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                Task {
                    self.clear(process: process)
                }
                continuation.resume(throwing: error)
            }
        }
    }

    public func cancel() async {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
        }
    }

    private func clear(process: Process) {
        if self.process === process {
            self.process = nil
        }
    }
}

public struct ShellBrowserOpener: BrowserOpening {
    public init() {}

    public func open(url: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BrowserOpenError.exitCode(process.terminationStatus)
        }
    }
}

private enum BrowserOpenError: LocalizedError {
    case exitCode(Int32)

    var errorDescription: String? {
        switch self {
        case let .exitCode(code):
            return "Browser open failed with exit code \(code)."
        }
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
