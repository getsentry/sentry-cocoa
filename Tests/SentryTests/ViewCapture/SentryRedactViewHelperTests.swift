#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import UIKit
import XCTest

final class SentryRedactViewHelperTests: XCTestCase {

    override func tearDown() {
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
        super.tearDown()
    }

    func testShouldMaskView_whenViewIsNotMasked_shouldReturnFalse() {
        // -- Arrange --
        let view = UIView()

        // -- Act --
        let value = SentryRedactViewHelper.shouldMaskView(view)

        // -- Assert --
        XCTAssertFalse(value)
    }

    func testShouldMaskView_whenViewIsMasked_shouldReturnTrue() {
        // -- Arrange --
        let view = UIView()
        SentryRedactViewHelper.maskView(view)

        // -- Act --
        let value = SentryRedactViewHelper.shouldMaskView(view)

        // -- Assert --
        XCTAssertTrue(value)
    }

    func testShouldUnmask_whenViewIsNotUnmasked_shouldReturnFalse() {
        // -- Arrange --
        let view = UIView()

        // -- Act --
        let value = SentryRedactViewHelper.shouldUnmask(view)

        // -- Assert --
        XCTAssertFalse(value)
    }

    func testShouldUnmask_whenViewIsUnmasked_shouldReturnTrue() {
        // -- Arrange --
        let view = UIView()
        SentryRedactViewHelper.unmaskView(view)

        // -- Act --
        let value = SentryRedactViewHelper.shouldUnmask(view)

        // -- Assert --
        XCTAssertTrue(value)
    }

    func testShouldClipOut_whenViewIsNotClippedOut_shouldReturnFalse() {
        // -- Arrange --
        let view = UIView()

        // -- Act --
        let value = SentryRedactViewHelper.shouldClipOut(view)

        // -- Assert --
        XCTAssertFalse(value)
    }

    func testShouldClipOut_whenViewIsClippedOut_shouldReturnTrue() {
        // -- Arrange --
        let view = UIView()
        SentryRedactViewHelper.clipOutView(view)

        // -- Act --
        let value = SentryRedactViewHelper.shouldClipOut(view)

        // -- Assert --
        XCTAssertTrue(value)
    }

    func testShouldRedactSwiftUI_whenViewIsNotMasked_shouldReturnFalse() {
        // -- Arrange --
        let view = UIView()

        // -- Act --
        let value = SentryRedactViewHelper.shouldRedactSwiftUI(view)

        // -- Assert --
        XCTAssertFalse(value)
    }

    func testShouldRedactSwiftUI_whenViewIsMasked_shouldReturnTrue() {
        // -- Arrange --
        let view = UIView()
        SentryRedactViewHelper.maskSwiftUI(view)

        // -- Act --
        let value = SentryRedactViewHelper.shouldRedactSwiftUI(view)

        // -- Assert --
        XCTAssertTrue(value)
    }

    func testValue_whenAssociatedValueIsNil_shouldReturnDefaultValueWithoutLogging() {
        // -- Arrange --
        let logOutput = configureLogOutput()

        // -- Act --
        let value = SentryRedactViewHelper.value(from: nil)

        // -- Assert --
        XCTAssertFalse(value)
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testValue_whenAssociatedValueIsValid_shouldReturnValueWithoutLogging() {
        // -- Arrange --
        let logOutput = configureLogOutput()

        // -- Act --
        let value = SentryRedactViewHelper.value(from: .valid(true))

        // -- Assert --
        XCTAssertTrue(value)
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testValue_whenAssociatedValueIsInvalid_shouldLogErrorAndReturnDefaultValue() {
        // -- Arrange --
        let logOutput = configureLogOutput()

        // -- Act --
        let value = SentryRedactViewHelper.value(from: .invalid("invalid"))

        // -- Assert --
        XCTAssertFalse(value)
        XCTAssertTrue(logOutput.loggedMessages.contains {
            $0.contains("An invalid associated object value was set in SentryRedactViewHelper")
        })
    }

    private func configureLogOutput() -> TestLogOutput {
        let logOutput = TestLogOutput(logsToConsole: false)
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)
        return logOutput
    }
}
#endif
#endif
