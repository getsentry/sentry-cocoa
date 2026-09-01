@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)

class SentryReplayApiTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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
