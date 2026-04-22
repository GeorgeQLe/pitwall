import XCTest
@testable import PitwallAppSupport

final class LoginItemServiceTests: XCTestCase {
    func testDefaultInitialStateIsDisabled() {
        let service = InMemoryLoginItemService()
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 0)
    }

    func testHonorsInitiallyEnabledFlag() {
        let service = InMemoryLoginItemService(initiallyEnabled: true)
        XCTAssertTrue(service.isEnabled)
    }

    func testSetEnabledTrueFlipsState() throws {
        let service = InMemoryLoginItemService()

        try service.setEnabled(true)

        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 1)
    }

    func testSetEnabledFalseFlipsStateBack() throws {
        let service = InMemoryLoginItemService(initiallyEnabled: true)

        try service.setEnabled(false)

        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 1)
    }

    func testToggleIsIdempotentAndCallCountTracksEveryCall() throws {
        let service = InMemoryLoginItemService()

        try service.setEnabled(true)
        try service.setEnabled(true)
        try service.setEnabled(false)
        try service.setEnabled(false)

        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 4)
    }

    func testInjectedErrorIsPropagatedAndStateIsUnchanged() {
        let service = InMemoryLoginItemService()
        service.setEnabledError = LoginItemServiceError.requiresApproval

        XCTAssertThrowsError(try service.setEnabled(true)) { error in
            guard case LoginItemServiceError.requiresApproval = error else {
                XCTFail("expected .requiresApproval, got \(error)")
                return
            }
        }

        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 1)
    }

    func testRegistrationFailedSurfaceCarriesUnderlyingDescription() {
        let underlying = NSError(
            domain: "TestDomain",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "smappservice blew up"]
        )
        let error = LoginItemServiceError.registrationFailed(underlying: underlying)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("smappservice blew up") == true)
    }

    func testUnregistrationFailedSurfaceCarriesUnderlyingDescription() {
        let underlying = NSError(
            domain: "TestDomain",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "unregister failed"]
        )
        let error = LoginItemServiceError.unregistrationFailed(underlying: underlying)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("unregister failed") == true)
    }

    func testClearingErrorAllowsSubsequentCallToSucceed() throws {
        let service = InMemoryLoginItemService()
        service.setEnabledError = LoginItemServiceError.notFound
        XCTAssertThrowsError(try service.setEnabled(true))

        service.setEnabledError = nil
        try service.setEnabled(true)

        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(service.setEnabledCallCount, 2)
    }
}
