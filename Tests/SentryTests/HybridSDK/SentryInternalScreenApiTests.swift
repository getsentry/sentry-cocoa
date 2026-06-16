@testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalScreenApiTests: XCTestCase {

    // MARK: - setCurrent

    func testSetCurrent_shouldCallConfigureScope() {
        // -- Arrange --
        let mockHub = MockHubProvider()
        let sut = SentryInternalScreenApi(dependencies: MockScreenDependencies(hubProvider: mockHub))

        // -- Act --
        sut.setCurrent("TestScreen")

        // -- Assert --
        XCTAssertTrue(mockHub.configureScopeCalled)
    }

    func testSetCurrent_withNil_shouldCallConfigureScope() {
        // -- Arrange --
        let mockHub = MockHubProvider()
        let sut = SentryInternalScreenApi(dependencies: MockScreenDependencies(hubProvider: mockHub))

        // -- Act --
        sut.setCurrent(nil)

        // -- Assert --
        XCTAssertTrue(mockHub.configureScopeCalled)
    }
}

// MARK: - Mock

private class MockHubProvider: HubProvider {
    var configureScopeCalled = false

    func configureScope(_ callback: @escaping (Scope) -> Void) {
        configureScopeCalled = true
        callback(Scope())
    }
}

private struct MockScreenDependencies: HubProviderProvider {
    var hubProvider: HubProvider
}

#endif
