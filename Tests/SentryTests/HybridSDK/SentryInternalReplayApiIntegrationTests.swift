@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalReplayApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalReplayApiIntegrationTests.self)
    private static let validReplayId = "0eac7ab503354dd5819b03e263627a29"

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - Helpers

    private func startSDKWithReplay() {
        SentrySDK.start { options in
            options.dsn = SentryInternalReplayApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
            options.sessionReplay = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        }
    }

    private func startSDKWithoutReplay() {
        SentrySDK.start { options in
            options.dsn = SentryInternalReplayApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    private func getReplayIntegration() throws -> SentrySessionReplayIntegration {
        try XCTUnwrap(SentrySDKInternal.currentHub().installedIntegrations().first as? SentrySessionReplayIntegration)
    }

    // MARK: - Accessor

    func testReplay_shouldBeAccessible() {
        startSDKWithReplay()

        // -- Act --
        let replay = SentrySDK.internal.replay

        // -- Assert --
        XCTAssertNotNil(replay)
    }

    // MARK: - capture

    func testCapture_withoutReplay_shouldReturnFalse() {
        startSDKWithoutReplay()

        // -- Act --
        let result = SentrySDK.internal.replay.capture()

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testCapture_withReplayEnabled_shouldNotCrashAndReturnBool() {
        startSDKWithReplay()

        // -- Act --
        let result = SentrySDK.internal.replay.capture()

        // -- Assert (no active replay session in test env, so capture returns false) --
        XCTAssertFalse(result)
    }

    func testCapture_withReplayEnabled_shouldFindReplayIntegration() throws {
        startSDKWithReplay()

        // -- Assert (the replay integration is installed and reachable) --
        let integration = SentrySDKInternal.currentHub().getInstalledIntegration(
            SentrySessionReplayIntegration.self
        )
        XCTAssertNotNil(integration, "Replay integration should be installed when sessionReplay is configured")
    }

    // MARK: - replayId

    func testReplayId_withoutReplay_shouldReturnNil() {
        startSDKWithoutReplay()

        // -- Act & Assert --
        XCTAssertNil(SentrySDK.internal.replay.replayId)
    }

    func testReplayId_whenSetOnScope_shouldReturnReplayId() {
        startSDKWithReplay()

        // -- Arrange --
        SentrySDKInternal.currentHub().scope.replayId = Self.validReplayId

        // -- Act --
        let result = SentrySDK.internal.replay.replayId

        // -- Assert --
        XCTAssertEqual(result, Self.validReplayId)
    }

    // MARK: - addIgnoreClasses

    func testAddIgnoreClasses_withReplayEnabled_shouldNotCrash() {
        let options = Options.noIntegrations()
        options.sessionReplay = SentryReplayOptions()
        SentrySDKInternal.start(options: options)

        // -- Act & Assert (no crash) --
        SentrySDK.internal.replay.addIgnoreClasses([UILabel.self])
    }

    // MARK: - addRedactClasses

    func testAddRedactClasses_withReplayEnabled_shouldNotCrash() {
        let options = Options.noIntegrations()
        options.sessionReplay = SentryReplayOptions()
        SentrySDKInternal.start(options: options)

        // -- Act & Assert (no crash) --
        SentrySDK.internal.replay.addRedactClasses([UILabel.self])
    }

    // MARK: - setIgnoreContainerClass

    func testSetIgnoreContainerClass_withReplayEnabled_shouldApplyToRedactBuilder() throws {
        startSDKWithReplay()

        // -- Act --
        SentrySDK.internal.replay.setIgnoreContainerClass(IgnoreContainerView.self)

        // -- Assert --
        let replayIntegration = try getReplayIntegration()
        let redactBuilder = replayIntegration.viewPhotographer.getRedactBuilder()
        XCTAssertTrue(redactBuilder.isIgnoreContainerClassTestOnly(IgnoreContainerView.self))
    }

    // MARK: - setRedactContainerClass

    func testSetRedactContainerClass_withReplayEnabled_shouldApplyToRedactBuilder() throws {
        startSDKWithReplay()

        // -- Act --
        SentrySDK.internal.replay.setRedactContainerClass(RedactContainerView.self)

        // -- Assert --
        let replayIntegration = try getReplayIntegration()
        let redactBuilder = replayIntegration.viewPhotographer.getRedactBuilder()
        XCTAssertTrue(redactBuilder.isRedactContainerClassTestOnly(RedactContainerView.self))
    }

    // MARK: - setTags

    func testSetTags_withoutReplay_shouldNotCrash() {
        startSDKWithoutReplay()

        // -- Act & Assert (no crash) --
        SentrySDK.internal.replay.setTags(["environment": "test"])
    }
}

// MARK: - Test helpers

private class IgnoreContainerView: UIView {}
private class RedactContainerView: UIView {}

#endif
