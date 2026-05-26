@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS)
import UIKit

final class UserFeedbackIntegrationTests: XCTestCase {

    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }

    private struct TestDependencies: ScreenshotSourceProvider {
        let screenshotSource: SentryScreenshotSource?
    }

    private final class TestWidgetTarget: NSObject {
        @objc func showForm() { }
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

    func testPresent_whenPresenterIsNotAttachedToWindow_shouldReturnFalse() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        XCTAssertFalse(sut.present(from: UIViewController(), screenshot: nil))
        XCTAssertFalse(sut.isDisplayingForm)
    }

    func testPresent_whenPresenterIsAttachedToWindow_shouldPresentFormWithScreenshot() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        let screenshot = UIImage()

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertTrue(sut.present(from: viewController, screenshot: screenshot))
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertIdentical(try XCTUnwrap(form.screenshot), screenshot)
        XCTAssertFalse(try XCTUnwrap(viewController.lastAnimated))
        XCTAssertTrue(sut.isDisplayingForm)

        withExtendedLifetime(window) { }
    }

    func testPresent_whenConfigurationBuildersAreSet_shouldNotApplyBuildersAgain() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        var configureFormCalls = 0
        var configureThemeCalls = 0
        config.configureForm = {
            configureFormCalls += 1
            $0.formTitle = "Custom title"
        }
        config.configureTheme = {
            configureThemeCalls += 1
            $0.background = .red
        }
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        XCTAssertTrue(sut.present(from: viewController, screenshot: nil))
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        XCTAssertEqual(form.config.formConfig.formTitle, "Custom title")
        XCTAssertEqual(form.config.theme.background, .red)

        withExtendedLifetime(window) { }
    }

    func testPresent_whenFormAlreadyPresented_shouldReturnFalse() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertTrue(sut.present(from: viewController, screenshot: nil))
        XCTAssertFalse(sut.present(from: viewController, screenshot: nil))

        withExtendedLifetime(window) { }
    }

    func testPresentationControllerDidDismiss_whenFormWasPresented_shouldClearActiveForm() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertTrue(sut.present(from: viewController, screenshot: nil))
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: viewController
        )

        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertFalse(sut.isDisplayingForm)

        withExtendedLifetime(window) { }
    }

    func testUninstall_whenDisplayingForm_shouldClearActiveForm() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertTrue(sut.present(from: viewController, screenshot: nil))
        sut.uninstall()

        XCTAssertFalse(sut.isDisplayingForm)

        withExtendedLifetime(window) { }
    }

    func testSetWidget_whenAnimatedHide_shouldHideButtonAfterAnimation() {
        let config = SentryUserFeedbackConfiguration()
        let target = TestWidgetTarget()
        let button = SentryUserFeedbackWidgetButtonView(config: config, target: target, selector: #selector(TestWidgetTarget.showForm))
        let sut = SentryUserFeedbackWidget.RootViewController(config: config, button: button)

        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        sut.setWidget(visible: false, animated: true)

        XCTAssertEqual(button.alpha, 0)
        XCTAssertTrue(button.isHidden)
        XCTAssertFalse(sut.isWidgetVisible)
    }

    func testFeedbackAPI_whenIntegrationIsMissing_shouldReturnFalse() {
        let previousHub = SentrySDKInternal.currentHub()
        SentrySDKInternal.setCurrentHub(TestHub(client: nil, andScope: nil))
        defer { SentrySDKInternal.setCurrentHub(previousHub) }

        let sut = SentryFeedbackAPI()

        XCTAssertFalse(sut.show())
    }

    // MARK: - Helper Types

    private final class TestPresentingViewController: UIViewController {
        private(set) var lastPresentedViewController: UIViewController?
        private(set) var lastAnimated: Bool?

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            lastPresentedViewController = viewControllerToPresent
            lastAnimated = flag
            completion?()
        }
    }
}

#endif
