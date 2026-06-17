@testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalScreenApiTests: XCTestCase {

    // MARK: - setCurrent

    func testSetCurrent_shouldCallConfigureScope() {
        // -- Arrange --
        let mockHub = MockHub()
        let sut = SentryInternalScreenApi(dependencies: MockScreenDependencies(hub: mockHub))

        // -- Act --
        sut.setCurrent("TestScreen")

        // -- Assert --
        XCTAssertTrue(mockHub.configureScopeCalled)
    }

    func testSetCurrent_withNil_shouldCallConfigureScope() {
        // -- Arrange --
        let mockHub = MockHub()
        let sut = SentryInternalScreenApi(dependencies: MockScreenDependencies(hub: mockHub))

        // -- Act --
        sut.setCurrent(nil)

        // -- Assert --
        XCTAssertTrue(mockHub.configureScopeCalled)
    }
}

// MARK: - Mock

private class MockHub: Hub {
    var configureScopeCalled = false

    func configureScope(_ callback: @escaping (Scope) -> Void) {
        configureScopeCalled = true
        callback(Scope())
    }

    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) {}
}

private struct MockScreenDependencies: HubProvider {
    var hub: Hub
}

#endif
