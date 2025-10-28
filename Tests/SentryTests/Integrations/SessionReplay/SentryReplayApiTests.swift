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

    func testStart_whenReplayIntegrationAlreadyInstalled_shouldCallStartOnExistingIntegration() {
        // Arrange
        let mockClient = TestClient(options: Options())
        let mockReplayIntegration = MockSessionReplayIntegration()
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        mockHub.addInstalledIntegration(mockReplayIntegration, name: "SentrySessionReplayIntegration")
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
        
        Dependencies.sessionReplayEnvironmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)

        // Act
        sut.start()

        // Assert
        XCTAssertTrue(mockHub.installedIntegrations().isEmpty)
    }

    func testStart_whenReplayIntegrationNilWithUnreliableEnvironmentAndExperimental_shouldCreateAndInstallIntegration() throws {
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
        
        Dependencies.sessionReplayEnvironmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)
        
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
        let hub = try XCTUnwrap(mockHub.installedIntegrations().first as? SentrySessionReplayIntegration)
        XCTAssertNotNil(hub.sessionReplay)
        XCTAssertTrue(hub.sessionReplay.isRunning)
        SentrySDKInternal.currentHub().endSession()
        XCTAssertTrue(hub.sessionReplay.isFullSession)
    }
}

// MARK: - Mock Classes

private class MockSessionReplayIntegration: SentrySessionReplayIntegration {
    var startCalled = false

    func install(with hub: SentryHub) -> Bool {
        return true
    }

    @objc override func start() {
        startCalled = true
    }
}

#endif // os(iOS) || os(tvOS)
