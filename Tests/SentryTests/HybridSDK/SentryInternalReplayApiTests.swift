@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if canImport(UIKit) && SENTRY_TARGET_REPLAY_SUPPORTED
import UIKit

class SentryInternalReplayApiTests: XCTestCase {

    private var sut: SentryInternalReplayApi { SentrySDK.internal.replay }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - replayId

    func testReplayId_whenNoReplayActive_shouldReturnNil() {
        // -- Act --
        let result = sut.replayId

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReplayId_whenReplayActive_shouldReturnId() {
        // -- Arrange --
        let client = TestClient(options: Options())
        let scope = Scope()
        scope.replayId = "0eac7ab503354dd5819b03e263627a29"
        SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: scope))

        // -- Act --
        let result = sut.replayId

        // -- Assert --
        XCTAssertEqual(result, "0eac7ab503354dd5819b03e263627a29")
    }

    // MARK: - addIgnoreClasses

    func testAddIgnoreClasses_whenReplayAvailable_shouldNotFail() {
        // -- Arrange --
        let options = Options.noIntegrations()
        options.sessionReplay = .init()
        SentrySDKInternal.start(options: options)

        // -- Act / Assert (no crash) --
        sut.addIgnoreClasses([UILabel.self])
    }

    // MARK: - addRedactClasses

    func testAddRedactClasses_whenReplayAvailable_shouldNotFail() {
        // -- Arrange --
        let options = Options()
        options.sessionReplay = .init()
        SentrySDKInternal.start(options: options)

        // -- Act / Assert (no crash) --
        sut.addRedactClasses([UILabel.self])
    }

    // MARK: - setIgnoreContainerClass

    func testSetIgnoreContainerClass_shouldRegisterWithRedactBuilder() throws {
        // -- Arrange --
        class IgnoreContainer: UIView {}

        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.sessionReplay = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        }

        // -- Act --
        sut.setIgnoreContainerClass(IgnoreContainer.self)

        // -- Assert --
        let replayIntegration = try XCTUnwrap(
            SentrySDKInternal.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        )
        let redactBuilder = replayIntegration.viewPhotographer.getRedactBuilder()
        XCTAssertTrue(redactBuilder.isIgnoreContainerClassTestOnly(IgnoreContainer.self))
    }

    // MARK: - setRedactContainerClass

    func testSetRedactContainerClass_shouldRegisterWithRedactBuilder() throws {
        // -- Arrange --
        class RedactContainer: UIView {}

        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.sessionReplay = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        }

        // -- Act --
        sut.setRedactContainerClass(RedactContainer.self)

        // -- Assert --
        let replayIntegration = try XCTUnwrap(
            SentrySDKInternal.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration
        )
        let redactBuilder = replayIntegration.viewPhotographer.getRedactBuilder()
        XCTAssertTrue(redactBuilder.isRedactContainerClassTestOnly(RedactContainer.self))
    }
}

#endif
