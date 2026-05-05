import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryReplayApiTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests

    func testStart_whenReplayIntegrationAlreadyInstalled_shouldCallStartOnExistingIntegration() throws {
        // Arrange
        let options = Options()
        options.sessionReplay.sessionSampleRate = 1.0
        let mockClient = TestClient(options: options)
        let mockReplayIntegration = try XCTUnwrap(MockSessionReplayIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        mockReplayIntegration.addItselfToSentryHub(hub: mockHub)
        SentrySDKInternal.setCurrentHub(mockHub)
        
        let sut = SentryReplayApi()

        // Act
        sut.start()

        // Assert
        XCTAssertTrue(mockReplayIntegration.startCalled)
        XCTAssertEqual(mockHub.installedIntegrations().count, 1) // No new integration added
    }
}

private class MockSessionReplayIntegration: SentrySessionReplayIntegration {
    var startCalled = false
    
    required convenience init?(with options: Options, dependencies: SentryDependencyContainer) {
        self.init(nonOptionalWith: options, dependencies: dependencies)
    }
    
    @objc override func start() {
        startCalled = true
    }
}

#endif // os(iOS) || os(tvOS)
