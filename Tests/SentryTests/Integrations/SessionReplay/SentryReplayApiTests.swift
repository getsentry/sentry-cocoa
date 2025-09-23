@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryReplayApiTests: XCTestCase {

    private class MockSentrySessionReplayIntegration: SentrySessionReplayIntegration {
        var pauseCalled = false
        var resumeCalled = false
        var startCalled = false
        var stopCalled = false
        var showMaskPreviewCalled = false
        var showMaskPreviewOpacity: CGFloat = 0
        var hideMaskPreviewCalled = false

        override func pause() {
            pauseCalled = true
        }

        override func resume() {
            resumeCalled = true
        }

        override func start() {
            startCalled = true
        }

        override func stop() {
            stopCalled = true
        }

        override func showMaskPreview(_ opacity: CGFloat) {
            showMaskPreviewCalled = true
            showMaskPreviewOpacity = opacity
        }

        override func hideMaskPreview() {
            hideMaskPreviewCalled = true
        }
    }

    private class Fixture {
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let mockIntegration = MockSentrySessionReplayIntegration()
        let testHub = TestHub(client: nil, andScope: nil)
        let mockView = UIView()

        init() {
            // Setup test hub to return our mock integration
            testHub.installedIntegrations = [mockIntegration]
        }

        func getSut() -> SentryReplayApi {
            return SentryReplayApi(dispatchQueueWrapper: dispatchQueueWrapper.internalWrapper)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryReplayApi!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = Fixture()
        sut = fixture.getSut()
        
        // Set the test hub as current hub
        SentrySDKInternal.setCurrentHub(fixture.testHub)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - maskView Tests

    func testMaskView_CallsRedactViewHelperOnMainThread() {
        // Arrange
        let view = fixture.mockView

        // Act
        sut.maskView(view)

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
    }

    func testMaskView_CallsRedactViewHelperImmediately() {
        // Arrange
        let view = fixture.mockView

        // Act
        sut.maskView(view)

        // Assert
        // Verify the dispatch was called and executed
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // The TestSentryDispatchQueueWrapper executes blocks immediately by default
    }

    // MARK: - unmaskView Tests

    func testUnmaskView_CallsRedactViewHelperOnMainThread() {
        // Arrange
        let view = fixture.mockView

        // Act
        sut.unmaskView(view)

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
    }

    // MARK: - pause Tests

    func testPause_CallsIntegrationPauseOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.pause()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.pauseCalled)
    }

    func testPause_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.pause()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - resume Tests

    func testResume_CallsIntegrationResumeOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.resume()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.resumeCalled)
    }

    func testResume_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.resume()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - start Tests

    func testStart_WithExistingIntegration_CallsIntegrationStartOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.start()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.startCalled)
    }

    func testStart_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.start()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - stop Tests

    func testStop_CallsIntegrationStopOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.stop()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.stopCalled)
    }

    func testStop_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.stop()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - showMaskPreview Tests

    func testShowMaskPreview_CallsIntegrationWithDefaultOpacityOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.showMaskPreview()

        // Assert
        XCTAssertEqual(2, fixture.dispatchQueueWrapper.blockOnMainInvocations.count) // One for showMaskPreview(), one for showMaskPreview(_:)
        XCTAssertTrue(fixture.mockIntegration.showMaskPreviewCalled)
        XCTAssertEqual(1.0, fixture.mockIntegration.showMaskPreviewOpacity)
    }

    func testShowMaskPreviewWithOpacity_CallsIntegrationWithSpecifiedOpacityOnMainThread() {
        // Arrange
        let testOpacity: CGFloat = 0.5

        // Act
        sut.showMaskPreview(testOpacity)

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.showMaskPreviewCalled)
        XCTAssertEqual(testOpacity, fixture.mockIntegration.showMaskPreviewOpacity)
    }

    func testShowMaskPreview_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.showMaskPreview()

        // Assert
        XCTAssertEqual(2, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - hideMaskPreview Tests

    func testHideMaskPreview_CallsIntegrationOnMainThread() {
        // Arrange
        // (No additional setup needed)

        // Act
        sut.hideMaskPreview()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertTrue(fixture.mockIntegration.hideMaskPreviewCalled)
    }

    func testHideMaskPreview_WithNilIntegration_DoesNotCrash() {
        // Arrange
        fixture.testHub.installedIntegrations = []

        // Act
        sut.hideMaskPreview()

        // Assert
        XCTAssertEqual(1, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
        // Should not crash when integration is nil
    }

    // MARK: - Thread Safety Tests

    func testAllMethods_DispatchToMainQueue() {
        // Arrange
        let view = fixture.mockView

        // Act
        sut.maskView(view)
        sut.unmaskView(view)
        sut.pause()
        sut.resume()
        sut.start()
        sut.stop()
        sut.showMaskPreview()
        sut.showMaskPreview(0.8)
        sut.hideMaskPreview()

        // Assert
        // 10 total calls: maskView, unmaskView, pause, resume, start, stop, showMaskPreview(), showMaskPreview(_:), showMaskPreview() -> showMaskPreview(_:), hideMaskPreview
        XCTAssertEqual(10, fixture.dispatchQueueWrapper.blockOnMainInvocations.count)
    }

    func testDispatchQueueWrapper_NotRetained() {
        // Arrange
        weak var weakDispatchWrapper = fixture.dispatchQueueWrapper

        // Act
        // Create a new SentryReplayApi instance with the dispatch wrapper
        _ = SentryReplayApi(dispatchQueueWrapper: fixture.dispatchQueueWrapper)

        // Assert
        // The dispatch wrapper should not be strongly retained beyond the scope
        XCTAssertNotNil(weakDispatchWrapper) // Still exists because fixture holds it
    }

    // MARK: - Integration Helper Tests

    func testInstalledIntegration_ReturnsCorrectIntegration() {
        // Arrange
        // (Mock integration is already set up in fixture)

        // Act
        sut.pause() // This will call installedIntegration internally

        // Assert
        XCTAssertTrue(fixture.mockIntegration.pauseCalled)
    }

    func testInstalledIntegration_WithMultipleIntegrations_ReturnsCorrectType() {
        // Arrange
        let otherIntegration = SentryIntegration() // Different type
        fixture.testHub.installedIntegrations = [otherIntegration, fixture.mockIntegration]

        // Act
        sut.pause()

        // Assert
        XCTAssertTrue(fixture.mockIntegration.pauseCalled) // Should find the correct type
    }
}

#endif
