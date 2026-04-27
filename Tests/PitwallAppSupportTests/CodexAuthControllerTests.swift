import XCTest
@testable import PitwallAppSupport

final class CodexAuthControllerTests: XCTestCase {
    func testStatusParsesChatGPTLogin() async {
        let controller = CodexAuthController(
            commandRunner: StubRunner(
                responses: [
                    .init(stdout: "Logged in using ChatGPT", exitCode: 0)
                ]
            ),
            deviceAuthRunner: StubDeviceAuthRunner(),
            browserOpener: StubBrowserOpener()
        )

        let status = await controller.status()

        XCTAssertEqual(status.status, .configured)
        XCTAssertEqual(status.authMode, .chatgpt)
        XCTAssertEqual(status.headline, "Connected with ChatGPT")
    }

    func testStatusParsesAPIKeyLogin() async {
        let controller = CodexAuthController(
            commandRunner: StubRunner(
                responses: [
                    .init(stdout: "Logged in using API key", exitCode: 0)
                ]
            ),
            deviceAuthRunner: StubDeviceAuthRunner(),
            browserOpener: StubBrowserOpener()
        )

        let status = await controller.status()

        XCTAssertEqual(status.status, .configured)
        XCTAssertEqual(status.authMode, .apiKey)
        XCTAssertEqual(status.headline, "Connected with API key")
    }

    func testStatusReturnsUnavailableWhenCommandFails() async {
        let controller = CodexAuthController(
            commandRunner: ThrowingRunner(),
            deviceAuthRunner: StubDeviceAuthRunner(),
            browserOpener: StubBrowserOpener()
        )

        let status = await controller.status()

        XCTAssertEqual(status.status, .unavailable)
        XCTAssertEqual(status.headline, "Codex CLI unavailable")
    }

    func testStartChatGPTLoginParsesDeviceFlowOpensBrowserAndRefreshesStatus() async throws {
        let runner = StubDeviceAuthRunner(
            events: [
                .stdout("Open this URL in your browser:\nhttps://chatgpt.com/device\n"),
                .stderr("Then enter code ABCD-EFGH\n")
            ],
            result: .success(.init(exitCode: 0))
        )
        let browser = StubBrowserOpener()
        let commandRunner = StubRunner(
            responses: [
                .init(stdout: "Logged in using ChatGPT", exitCode: 0)
            ]
        )
        let controller = CodexAuthController(
            commandRunner: commandRunner,
            deviceAuthRunner: runner,
            browserOpener: browser
        )

        let initial = await controller.startChatGPTLogin()
        XCTAssertEqual(initial.phase, .starting)

        let final = await waitForState(controller) { $0.phase == .succeeded }

        XCTAssertEqual(final.finalSetupState?.status, .configured)
        XCTAssertEqual(final.finalSetupState?.authMode, .chatgpt)
        let opened = await browser.openedURLs()
        XCTAssertEqual(opened, ["https://chatgpt.com/device"])
        let invocations = await commandRunner.invocations()
        XCTAssertEqual(invocations.map(\.arguments), [["login", "status"]])
    }

    func testStartChatGPTLoginKeepsSessionActiveWhenBrowserOpenFails() async throws {
        let runner = StubDeviceAuthRunner(
            events: [
                .stdout("Visit https://chatgpt.com/device and enter code WXYZ-1234\n")
            ],
            result: .success(.init(exitCode: 1)),
            holdUntilCancelled: true
        )
        let browser = StubBrowserOpener(error: StubBrowserOpener.OpenError.failed)
        let controller = CodexAuthController(
            commandRunner: StubRunner(responses: [.init(stdout: "Not logged in", exitCode: 0)]),
            deviceAuthRunner: runner,
            browserOpener: browser
        )

        _ = await controller.startChatGPTLogin()
        let state = await waitForState(controller) {
            $0.phase == .awaitingBrowser && $0.failureReason == .browserOpenFailed
        }

        XCTAssertEqual(state.deviceCode, "WXYZ-1234")
        XCTAssertEqual(state.verificationURL, "https://chatgpt.com/device")
        XCTAssertFalse(state.didOpenBrowser)
        XCTAssertTrue(state.canCancel)
    }

    func testRetryOpenChatGPTLoginBrowserUpdatesState() async throws {
        let runner = StubDeviceAuthRunner(
            events: [
                .stdout("Visit https://chatgpt.com/device and enter code RETRY-1234\n")
            ],
            result: .success(.init(exitCode: 1)),
            holdUntilCancelled: true
        )
        let browser = StubBrowserOpener(error: StubBrowserOpener.OpenError.failed)
        let controller = CodexAuthController(
            commandRunner: StubRunner(responses: [.init(stdout: "Not logged in", exitCode: 0)]),
            deviceAuthRunner: runner,
            browserOpener: browser
        )

        _ = await controller.startChatGPTLogin()
        _ = await waitForState(controller) { $0.failureReason == .browserOpenFailed }
        await browser.setError(nil)

        let retried = await controller.retryOpenChatGPTLoginBrowser()

        XCTAssertEqual(retried.phase, .waitingForConfirmation)
        XCTAssertTrue(retried.didOpenBrowser)
    }

    func testStartChatGPTLoginTimesOutWhenOutputCannotBeParsed() async throws {
        let runner = StubDeviceAuthRunner(
            events: [],
            result: .success(.init(exitCode: 1)),
            holdUntilCancelled: true
        )
        let controller = CodexAuthController(
            commandRunner: StubRunner(),
            deviceAuthRunner: runner,
            browserOpener: StubBrowserOpener(),
            parseTimeoutNanoseconds: 1_000_000,
            sessionTimeoutNanoseconds: 5_000_000_000
        )

        _ = await controller.startChatGPTLogin()
        let final = await waitForState(controller) { $0.phase == .failed }

        XCTAssertEqual(final.failureReason, .startupParseTimeout)
        XCTAssertNil(final.deviceCode)
        XCTAssertNil(final.verificationURL)
    }

    func testStartChatGPTLoginMapsRejectedLoginWithoutLeakingOutput() async throws {
        let runner = StubDeviceAuthRunner(
            events: [
                .stdout("Visit https://chatgpt.com/device and enter code HIDE-9999\n")
            ],
            result: .success(.init(
                stderr: "Login rejected for code HIDE-9999 with token sk-secret",
                exitCode: 1
            ))
        )
        let controller = CodexAuthController(
            commandRunner: StubRunner(responses: [.init(stdout: "Not logged in", exitCode: 0)]),
            deviceAuthRunner: runner,
            browserOpener: StubBrowserOpener()
        )

        _ = await controller.startChatGPTLogin()
        let final = await waitForState(controller) { $0.phase == .failed }

        XCTAssertEqual(final.failureReason, .loginRejected)
        XCTAssertFalse(final.message.contains("HIDE-9999"))
        XCTAssertFalse(final.message.contains("sk-secret"))
        XCTAssertNil(final.deviceCode)
        XCTAssertNil(final.verificationURL)
    }

    func testCancelChatGPTLoginTerminatesActiveSession() async throws {
        let runner = StubDeviceAuthRunner(
            events: [
                .stdout("Visit https://chatgpt.com/device and enter code STOP-1234\n")
            ],
            result: .success(.init(exitCode: 1)),
            holdUntilCancelled: true
        )
        let controller = CodexAuthController(
            commandRunner: StubRunner(),
            deviceAuthRunner: runner,
            browserOpener: StubBrowserOpener()
        )

        _ = await controller.startChatGPTLogin()
        _ = await waitForState(controller) { $0.phase == .waitingForConfirmation || $0.phase == .awaitingBrowser }

        let cancelled = await controller.cancelChatGPTLogin()
        let cancelCallCount = await runner.cancelCallCount()

        XCTAssertEqual(cancelled.phase, .cancelled)
        XCTAssertEqual(cancelled.failureReason, .cancelledByUser)
        XCTAssertEqual(cancelCallCount, 2)
    }

    func testLoginWithAPIKeyWritesToStdinAndParsesConfiguredState() async throws {
        let runner = StubRunner(
            responses: [
                .init(stdout: "Logged in using API key", exitCode: 0)
            ]
        )
        let controller = CodexAuthController(
            commandRunner: runner,
            deviceAuthRunner: StubDeviceAuthRunner(),
            browserOpener: StubBrowserOpener()
        )

        let status = try await controller.loginWithAPIKey("sk-test")

        XCTAssertEqual(status.status, .configured)
        XCTAssertEqual(status.authMode, .apiKey)
        let invocations = await runner.invocations()
        let invocation = invocations.first
        XCTAssertEqual(invocation?.arguments, ["login", "--with-api-key"])
        XCTAssertEqual(invocation?.stdin, "sk-test\n")
    }

    func testLogoutReturnsMissingState() async throws {
        let runner = StubRunner(
            responses: [
                .init(stdout: "", exitCode: 0),
                .init(stdout: "Not logged in", exitCode: 0)
            ]
        )
        let controller = CodexAuthController(
            commandRunner: runner,
            deviceAuthRunner: StubDeviceAuthRunner(),
            browserOpener: StubBrowserOpener()
        )

        let status = try await controller.logout()

        XCTAssertEqual(status.status, .missing)
        XCTAssertEqual(status.headline, "Codex login not detected")
    }

    private func waitForState(
        _ controller: CodexAuthController,
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        predicate: @escaping (CodexDeviceAuthSessionState) -> Bool
    ) async -> CodexDeviceAuthSessionState {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let state = await controller.currentChatGPTLoginState()
            if predicate(state) {
                return state
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        return await controller.currentChatGPTLoginState()
    }
}

private actor StubRunner: CodexCommandRunning {
    struct Invocation: Equatable {
        var arguments: [String]
        var stdin: String?
    }

    private var queuedResponses: [ProcessExecutionResult]
    private var seenInvocations: [Invocation] = []

    init(responses: [ProcessExecutionResult] = []) {
        self.queuedResponses = responses
    }

    func run(arguments: [String], stdin: Data?) async throws -> ProcessExecutionResult {
        seenInvocations.append(Invocation(
            arguments: arguments,
            stdin: stdin.flatMap { String(data: $0, encoding: .utf8) }
        ))
        if queuedResponses.isEmpty {
            return ProcessExecutionResult()
        }
        return queuedResponses.removeFirst()
    }

    func invocations() -> [Invocation] {
        seenInvocations
    }
}

private actor ThrowingRunner: CodexCommandRunning {
    func run(arguments: [String], stdin: Data?) async throws -> ProcessExecutionResult {
        struct Failure: Error {}
        throw Failure()
    }
}

private actor StubDeviceAuthRunner: CodexDeviceAuthFlowRunning {
    private let events: [CodexDeviceAuthStreamEvent]
    private let result: Result<ProcessExecutionResult, Error>
    private let holdUntilCancelled: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private var cancelCalls = 0

    init(
        events: [CodexDeviceAuthStreamEvent] = [],
        result: Result<ProcessExecutionResult, Error> = .success(ProcessExecutionResult()),
        holdUntilCancelled: Bool = false
    ) {
        self.events = events
        self.result = result
        self.holdUntilCancelled = holdUntilCancelled
    }

    func runDeviceAuth(
        onEvent: @escaping @Sendable (CodexDeviceAuthStreamEvent) async -> Void
    ) async throws -> ProcessExecutionResult {
        for event in events {
            await onEvent(event)
        }

        if holdUntilCancelled {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }

    func cancel() async {
        cancelCalls += 1
        continuation?.resume()
        continuation = nil
    }

    func cancelCallCount() -> Int {
        cancelCalls
    }
}

private actor StubBrowserOpener: BrowserOpening {
    enum OpenError: Error {
        case failed
    }

    private var error: Error?
    private var urls: [String] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func open(url: URL) async throws {
        urls.append(url.absoluteString)
        if let error {
            throw error
        }
    }

    func setError(_ error: Error?) {
        self.error = error
    }

    func openedURLs() -> [String] {
        urls
    }
}
