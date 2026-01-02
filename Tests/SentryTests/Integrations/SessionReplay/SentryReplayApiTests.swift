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
        // Ensure the integration will always be enabled
        options.experimental.enableSessionReplayInUnreliableEnvironment = true
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

    func testStart_whenReplayIntegrationNilAndUnreliableToEnable_shouldNotCreateIntegration() {
        // Arrange
        let options = Options()
        options.sessionReplay = SentryReplayOptions(sessionSampleRate: 1.0, onErrorSampleRate: 1.0)
        options.experimental.enableSessionReplayInUnreliableEnvironment = false
        let mockClient = TestClient(options: options)
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        SentrySDKInternal.setCurrentHub(mockHub)
        
        let sut = SentryReplayApi()
        
        SentryDependencyContainer.sharedInstance().sessionReplayEnvironmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)

        // Act
        sut.start()

        // Assert
        XCTAssertTrue(mockHub.installedIntegrations().isEmpty)
    }

    func testStart_whenReplayIntegrationNilWithUnreliableEnvironmentAndOverrideOptionEnabled_shouldCreateAndInstallIntegration() throws {
        // Arrange
        let options = Options()
        options.sessionReplay = SentryReplayOptions(sessionSampleRate: 1.0, onErrorSampleRate: 1.0)
        options.experimental.enableSessionReplayInUnreliableEnvironment = true
        options.dsn = "https://user@test.com/test"
        let mockClient = TestClient(options: options)
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        SentrySDKInternal.setCurrentHub(mockHub)
        
        let sut = SentryReplayApi()
        
        SentryDependencyContainer.sharedInstance().sessionReplayEnvironmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)
        
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        SentryDependencyContainer.sharedInstance().fileManager = try SentryFileManager(
            options: options,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
            dispatchQueueWrapper: dispatchQueue
        )
        
        // Act
        sut.start()
        
        // Assert
        XCTAssertEqual(mockHub.installedIntegrations().count, 1)
        let integration = try XCTUnwrap(mockHub.installedIntegrations().first as? SentrySessionReplayIntegration)
        XCTAssertNotNil(integration.sessionReplay)
        XCTAssertTrue(integration.sessionReplay?.isRunning ?? false)
        SentrySDKInternal.currentHub().endSession()
        XCTAssertTrue(integration.sessionReplay?.isFullSession ?? false)
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
