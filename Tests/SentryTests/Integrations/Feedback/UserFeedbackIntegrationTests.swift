@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS)

final class UserFeedbackIntegrationTests: XCTestCase {
    
    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }
    
    private struct TestDependencies: ScreenshotSourceProvider {
        let screenshotSource: SentryScreenshotSource?
    }

    private func makeScreenshotSource() -> SentryScreenshotSource {
        let viewRenderer = SentryDefaultViewRenderer()
        let photographer = SentryViewPhotographer(
            renderer: viewRenderer,
            redactOptions: Options().screenshot,
            enableMaskRendererV2: false)
        return SentryScreenshotSource(photographer: photographer)
    }
    
    func testUsesCorrectName() {
        XCTAssertEqual(UserFeedbackIntegration<TestDependencies>.name, "SentryUserFeedbackIntegration")
    }
    
    func testInitializerFailsWhenNoScreenshotSource() {
        let integration = UserFeedbackIntegration(with: Self.optionsWithFeedback, dependencies: TestDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }
    
    func testInitializerSucceedsWhenScreenshotSourceIsPresent() {
        let integration = UserFeedbackIntegration(
            with: Self.optionsWithFeedback,
            dependencies: TestDependencies(screenshotSource: makeScreenshotSource()))
        XCTAssertNotNil(integration)
    }
    
    func testInitializerFailsWhenFeedbackNotConfigured() {
        let integration = UserFeedbackIntegration(with: Options(), dependencies: TestDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }

    func testDriverPresentationLifecycleCallsHooksAndCapturesFeedback() throws {
        let config = SentryUserFeedbackConfiguration()
        var openCount = 0
        var closeCount = 0
        var capturedFeedback = [SentryFeedback]()
        config.onFormOpen = { openCount += 1 }
        config.onFormClose = { closeCount += 1 }

        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource()) { feedback in
                capturedFeedback.append(feedback)
        }
        let feedback = SentryFeedback(message: "message", name: nil, email: nil)

        XCTAssertTrue(sut.beginPresentation(.swiftUI))
        sut.formDidOpen()
        sut.formDidOpen()
        sut.formDidFinish(feedback: feedback)
        sut.finishPresentation()

        XCTAssertEqual(openCount, 1)
        XCTAssertEqual(closeCount, 1)
        XCTAssertEqual(capturedFeedback.count, 1)
        XCTAssertIdentical(try XCTUnwrap(capturedFeedback.first), feedback)
    }

    func testDriverCapturesFeedbackWhenFormFinishes() throws {
        var capturedFeedback = [SentryFeedback]()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { feedback in
                capturedFeedback.append(feedback)
        }
        let feedback = SentryFeedback(message: "message", name: nil, email: nil)

        XCTAssertTrue(sut.beginPresentation(.swiftUI))
        sut.formDidFinish(feedback: feedback)

        XCTAssertEqual(capturedFeedback.count, 1)
        XCTAssertIdentical(try XCTUnwrap(capturedFeedback.first), feedback)

        sut.finishPresentation()
    }

    func testDriverDoesNotStartPresentationTwice() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        XCTAssertTrue(sut.beginPresentation(.swiftUI))
        XCTAssertFalse(sut.beginPresentation(.swiftUI))

        sut.finishPresentation()
    }

    func testDriverFinishesSwiftUIPresentationLifecycle() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        XCTAssertFalse(sut.isDisplayingForm)
        XCTAssertFalse(sut.isPresenting(.swiftUI))

        XCTAssertTrue(sut.beginPresentation(.swiftUI))
        XCTAssertTrue(sut.isDisplayingForm)
        XCTAssertTrue(sut.isPresenting(.swiftUI))

        sut.finishPresentation()
        XCTAssertFalse(sut.isDisplayingForm)
        XCTAssertFalse(sut.isPresenting(.swiftUI))
    }

    func testDriverDoesNotCallCloseHookWhenFormDidNotOpen() {
        let config = SentryUserFeedbackConfiguration()
        var closeCount = 0
        config.onFormClose = { closeCount += 1 }
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource()) { _ in }

        XCTAssertTrue(sut.beginPresentation(.swiftUI))
        sut.finishPresentation()

        XCTAssertEqual(closeCount, 0)
    }
}

#endif
