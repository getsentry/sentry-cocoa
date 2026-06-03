@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS)
import UIKit

final class UserFeedbackIntegrationTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

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

    func testGlobalConfigurationOrDefault_whenGlobalFeedbackConfigured_shouldUsePreparedDriverConfiguration() throws {
        let options = Options()
        var configureFormCalls = 0
        options.configureUserFeedback = { config in
            config.configureForm = {
                configureFormCalls += 1
                $0.formTitle = "Global title"
            }
        }
        SentrySDK.setStart(with: options)
        let integration = try XCTUnwrap(UserFeedbackIntegration<SentryDependencyContainer>(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()))
        SentrySDKInternal.currentHub().addInstalledIntegration(
            integration,
            name: UserFeedbackIntegration<SentryDependencyContainer>.name)

        XCTAssertEqual(configureFormCalls, 1)
        let sut = SentryUserFeedbackFormController.globalConfigurationOrDefault()

        XCTAssertIdentical(sut, integration.driver.configuration)
        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(sut.formConfig.formTitle, "Global title")
    }

    func testGlobalConfigurationOrDefault_whenGlobalFeedbackNotConfigured_shouldPrepareDefaultConfiguration() {
        clearTestState()
        let defaultConfig = SentryUserFeedbackConfiguration()
        var configureFormCalls = 0
        var configureThemeCalls = 0
        defaultConfig.configureForm = {
            configureFormCalls += 1
            $0.formTitle = "Prepared default title"
        }
        defaultConfig.configureTheme = {
            configureThemeCalls += 1
            $0.background = .red
        }

        let sut = SentryUserFeedbackFormController.globalConfigurationOrDefault(
            defaultConfiguration: defaultConfig)

        XCTAssertIdentical(sut, defaultConfig)
        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        XCTAssertEqual(sut.formConfig.formTitle, "Prepared default title")
        XCTAssertEqual(sut.theme.background, .red)
    }

    func testShowForm_whenNoPresenterAvailable_shouldNotPresentForm() {
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        sut.showForm()

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
        sut.showForm(from: viewController, screenshot: nil)
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertEqual(configureFormCalls, 1)
        XCTAssertEqual(configureThemeCalls, 1)
        XCTAssertEqual(form.config.formConfig.formTitle, "Custom title")
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

        sut.showForm(from: viewController, screenshot: nil)
        sut.showForm(from: viewController, screenshot: nil)

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

        sut.showForm(from: viewController, screenshot: nil)
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
        let widgetHost = try XCTUnwrap(widgetHost(for: sut))

        XCTAssertTrue(widgetHost.isWidgetVisible)
        sut.showForm()
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

    // MARK: - Helper Types

    private func widgetHost(for driver: SentryUserFeedbackIntegrationDriver) -> SentryUserFeedbackWidget.RootViewController? {
        let widget = Mirror(reflecting: driver)
            .children
            .first { $0.label == "widget" }?
            .value as? SentryUserFeedbackWidget
        return widget?.rootVC
    }

    private func addCustomButton(to viewController: UIViewController, configuration: SentryUserFeedbackConfiguration) {
        let customButton = UIButton()
        configuration.customButton = customButton
        viewController.view.addSubview(customButton)
    }

    private final class TestPresentingViewController: UIViewController {
        private(set) var lastPresentedViewController: UIViewController?
        private(set) var presentCallCount = 0

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated _: Bool,
            completion: (() -> Void)? = nil
        ) {
            presentCallCount += 1
            lastPresentedViewController = viewControllerToPresent
            completion?()
        }
    }
}

#endif
