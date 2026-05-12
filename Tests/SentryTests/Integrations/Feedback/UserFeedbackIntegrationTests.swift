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

    private final class TestFeedbackFormPresenter: SentryFeedbackFormPresenter {
        weak var delegate: SentryFeedbackFormPresenterDelegate?
        var shouldPresent = true
        private(set) var presentCount = 0
        private(set) var lastScreenshot: UIImage?
        private(set) var dismissCount = 0

        @discardableResult
        func present(screenshot: UIImage?) -> Bool {
            presentCount += 1
            lastScreenshot = screenshot
            return shouldPresent
        }

        func dismiss() {
            dismissCount += 1
            delegate?.feedbackFormPresenterDidDismiss(self)
        }
    }

    private final class WeakReference<T: AnyObject> {
        weak var value: T?

        init(_ value: T?) {
            self.value = value
        }
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
        let presenter = TestFeedbackFormPresenter()
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

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        sut.formDidOpen()
        sut.formDidOpen()
        sut.finished(with: feedback)

        XCTAssertEqual(openCount, 1)
        XCTAssertEqual(closeCount, 1)
        XCTAssertEqual(capturedFeedback.count, 1)
        XCTAssertIdentical(try XCTUnwrap(capturedFeedback.first), feedback)
        XCTAssertEqual(presenter.dismissCount, 1)
        XCTAssertNil(presenter.delegate)
    }

    func testDriverCapturesFeedbackWhenFormFinishes() throws {
        let presenter = TestFeedbackFormPresenter()
        var capturedFeedback = [SentryFeedback]()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { feedback in
                capturedFeedback.append(feedback)
        }
        let feedback = SentryFeedback(message: "message", name: nil, email: nil)

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        sut.finished(with: feedback)

        XCTAssertEqual(capturedFeedback.count, 1)
        XCTAssertIdentical(try XCTUnwrap(capturedFeedback.first), feedback)
    }

    func testDriverDoesNotStartPresentationTwice() {
        let presenter = TestFeedbackFormPresenter()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        XCTAssertFalse(sut.presentForm())
        XCTAssertEqual(presenter.presentCount, 1)

        presenter.dismiss()
    }

    func testDriverFinishesPresentationLifecycle() {
        let presenter = TestFeedbackFormPresenter()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        XCTAssertFalse(sut.isDisplayingForm)

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        XCTAssertTrue(sut.isDisplayingForm)

        presenter.dismiss()
        XCTAssertFalse(sut.isDisplayingForm)
    }

    func testDriverDoesNotCallCloseHookWhenFormDidNotOpen() {
        let config = SentryUserFeedbackConfiguration()
        let presenter = TestFeedbackFormPresenter()
        var closeCount = 0
        config.onFormClose = { closeCount += 1 }
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource()) { _ in }

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        presenter.dismiss()

        XCTAssertEqual(closeCount, 0)
    }

    func testDriverPassesScreenshotToPresenter() throws {
        let presenter = TestFeedbackFormPresenter()
        let screenshot = UIImage()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm(screenshot: screenshot))

        XCTAssertIdentical(try XCTUnwrap(presenter.lastScreenshot), screenshot)

        presenter.dismiss()
    }

    func testDriverRetainsActivePresenterUntilDismissal() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }
        var presenter: TestFeedbackFormPresenter? = TestFeedbackFormPresenter()
        let weakPresenter = WeakReference(presenter)

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertTrue(sut.presentForm())
        presenter = nil

        XCTAssertNotNil(weakPresenter.value)
        XCTAssertTrue(sut.isDisplayingForm)

        weakPresenter.value?.dismiss()
        XCTAssertNil(weakPresenter.value)
        XCTAssertFalse(sut.isDisplayingForm)
    }

    func testDriverClearsDelegateWhenPresenterFails() {
        let presenter = TestFeedbackFormPresenter()
        presenter.shouldPresent = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource()) { _ in }

        sut.setFeedbackFormPresenter(presenter)
        XCTAssertFalse(sut.presentForm())

        XCTAssertFalse(sut.isDisplayingForm)
        XCTAssertNil(presenter.delegate)
    }
}

#endif
