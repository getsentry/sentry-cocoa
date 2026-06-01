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

    func testShowForm_whenNoPresenterAvailable_shouldNotPresentForm() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        sut.showForm(screenshot: nil)

        XCTAssertFalse(sut.displayingForm)
    }

    func testShowForm_whenConfigurationBuildersAreSet_shouldNotApplyBuildersAgain() throws {
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
        addCustomButton(to: viewController, configuration: config)
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        sut.showForm(screenshot: nil)
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        XCTAssertEqual(form.config.formTitle, "Custom title")
        XCTAssertEqual(form.config.theme.background, .red)

        withExtendedLifetime(window) { }
    }

    func testShowForm_whenFormAlreadyPresented_shouldNotPresentAgain() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        addCustomButton(to: viewController, configuration: config)
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        sut.showForm(screenshot: nil)
        sut.showForm(screenshot: nil)

        XCTAssertEqual(viewController.presentCallCount, 1)

        withExtendedLifetime(window) { }
    }

    func testPresentationControllerDidDismiss_whenFormWasPresented_shouldClearActiveForm() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        addCustomButton(to: viewController, configuration: config)
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        sut.showForm(screenshot: nil)
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: viewController
        )

        form.beginAppearanceTransition(true, animated: false)
        form.endAppearanceTransition()
        form.presentationControllerDidDismiss(presentationController)

        XCTAssertFalse(sut.displayingForm)

        withExtendedLifetime(window) { }
    }

    func testShowForm_whenWidgetIsPresenter_shouldHideWidgetUntilFormCloses() throws {
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        sut.showWidget()
        let widgetHost = try XCTUnwrap(sut.presenter as? SentryUserFeedbackWidget.RootViewController)

        XCTAssertTrue(widgetHost.isWidgetVisible)
        sut.showForm(screenshot: nil)
        XCTAssertFalse(widgetHost.isWidgetVisible)

        let form = try XCTUnwrap(widgetHost.presentedViewController as? SentryUserFeedbackFormController)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: widgetHost
        )

        form.beginAppearanceTransition(true, animated: false)
        form.endAppearanceTransition()
        form.presentationControllerDidDismiss(presentationController)

        XCTAssertTrue(widgetHost.isWidgetVisible)
    }

    func testFeedbackFormPresenter_whenKeyWindowPresenterAvailable_shouldReturnPresenter() throws {
        let viewController = UIViewController()
        let window = try makeKeyWindow(rootViewController: viewController)

        let presenter = try XCTUnwrap(SentryFeedbackFormPresenter.presentingViewController())

        XCTAssertIdentical(presenter, viewController)

        withExtendedLifetime(window) { }
    }

    func testShowWithConfig_whenKeyWindowPresenterAvailable_shouldPresentForm() throws {
        let viewController = TestPresentingViewController()
        let window = try makeKeyWindow(rootViewController: viewController)
        let config = SentryFeedbackFormConfig()
        config.animations = false
        config.formTitle = "Manual feedback"

        SentrySDK.feedback.show(config: config)

        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertEqual(form.config.formTitle, "Manual feedback")
        XCTAssertEqual(viewController.lastAnimated, false)

        withExtendedLifetime(window) { }
    }

    // MARK: - Helper Types

    private func addCustomButton(to viewController: UIViewController, configuration: SentryUserFeedbackConfiguration) {
        let customButton = UIButton()
        configuration.customButton = customButton
        viewController.view.addSubview(customButton)
    }

    private func makeKeyWindow(rootViewController: UIViewController) throws -> UIWindow {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw XCTSkip("No foreground-active window scene available")
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        rootViewController.loadViewIfNeeded()
        return window
    }

    private final class TestPresentingViewController: UIViewController {
        private(set) var lastPresentedViewController: UIViewController?
        private(set) var lastAnimated: Bool?
        private(set) var presentCallCount = 0

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            presentCallCount += 1
            lastPresentedViewController = viewControllerToPresent
            lastAnimated = flag
            completion?()
        }
    }
}

#endif
