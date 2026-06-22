@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS)
import UIKit

final class UserFeedbackIntegrationTests: XCTestCase {

    private static let mockWindowScene: UIWindowScene = MockUIWindowScene()

    private func makeWindow() -> UIWindow {
        let window = UIWindow(windowScene: Self.mockWindowScene)
        window.frame = UIScreen.main.bounds
        return window
    }

    private let mockWindowFactory: SentryUserFeedbackWindowFactory = { config in
        let window = SentryUserFeedbackWidget.Window(config: config, windowScene: mockWindowScene)
        return window
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }

    private struct TestDependencies: UserFeedbackIntegrationProvider {
        let screenshotSource: SentryScreenshotSource?
        var windowFactory: SentryUserFeedbackWindowFactory {
            SentryUserFeedbackWidget.defaultWindowFactory
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

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testWidgetAccessibilityLabel_whenLabelTextChangedBeforeAccess_shouldUseUpdatedLabelText() {
        let sut = SentryUserFeedbackWidgetConfiguration()

        sut.labelText = "Send Feedback"

        XCTAssertEqual(sut.widgetAccessibilityLabel, "Send Feedback")
    }

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testWidgetAccessibilityLabel_whenExplicitlySetToNil_shouldRemainNil() {
        let sut = SentryUserFeedbackWidgetConfiguration()

        sut.widgetAccessibilityLabel = nil

        XCTAssertNil(sut.widgetAccessibilityLabel)
    }

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testWidgetConfiguration_whenDeprecatedPropertiesAreSet_shouldRoundTripValues() {
        let sut = SentryUserFeedbackWidgetConfiguration()
        let layoutOffset = UIOffset(horizontal: 10, vertical: 20)
        let windowLevel = UIWindow.Level.alert + 1

        sut.autoInject = false
        sut.labelText = "Send Feedback"
        sut.showIcon = false
        sut.widgetAccessibilityLabel = "Feedback Button"
        sut.windowLevel = windowLevel
        sut.location = [.top, .leading]
        sut.layoutUIOffset = layoutOffset

        XCTAssertFalse(sut.autoInject)
        XCTAssertEqual(sut.labelText, "Send Feedback")
        XCTAssertFalse(sut.showIcon)
        XCTAssertEqual(sut.widgetAccessibilityLabel, "Feedback Button")
        XCTAssertEqual(sut.windowLevel, windowLevel)
        XCTAssertEqual(sut.location, [.top, .leading])
        XCTAssertEqual(sut.layoutUIOffset.horizontal, layoutOffset.horizontal)
        XCTAssertEqual(sut.layoutUIOffset.vertical, layoutOffset.vertical)
    }

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testConfigureWidget_whenSet_shouldStoreBuilder() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let sut = SentryUserFeedbackConfiguration()
        let widgetConfig = SentryUserFeedbackWidgetConfiguration()

        sut.configureWidget = { config in
            config.autoInject = false
        }
        try XCTUnwrap(sut.configureWidget)(widgetConfig)

        XCTAssertFalse(widgetConfig.autoInject)
#endif
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

    func testFeedbackForm_whenNoLocalConfiguration_shouldUseGlobalConfiguration() throws {
        let integration = try installFeedbackIntegration { config in
            config.configureForm = { $0.formTitle = "Global title" }
        }

        let sut = SentryUserFeedbackFormController()

        XCTAssertIdentical(sut.config, integration.driver.configuration)
        XCTAssertEqual(sut.config.formConfig.formTitle, "Global title")
    }

    func testFeedbackForm_whenLocalConfigurationIsSet_shouldApplyToCurrentFormOnly() throws {
        let integration = try installFeedbackIntegration { config in
            config.animations = true
            config.tags = ["source": "global"]
            config.configureForm = { $0.formTitle = "Global title" }
            config.configureTheme = { $0.background = .red }
        }

        let sut = SentryUserFeedbackFormController { config in
            config.animations = false
            config.tags = ["source": "local"]
            config.configureForm = { $0.formTitle = "Local title" }
            config.configureTheme = { $0.background = .blue }
        }

        XCTAssertNotIdentical(sut.config, integration.driver.configuration)
        XCTAssertFalse(sut.config.animations)
        XCTAssertEqual(try XCTUnwrap(sut.config.tags?["source"] as? String), "local")
        XCTAssertEqual(sut.config.formConfig.formTitle, "Local title")
        XCTAssertEqual(sut.config.theme.background, .blue)
        XCTAssertTrue(integration.driver.configuration.animations)
        XCTAssertEqual(try XCTUnwrap(integration.driver.configuration.tags?["source"] as? String), "global")
        XCTAssertEqual(integration.driver.configuration.formConfig.formTitle, "Global title")
        XCTAssertEqual(integration.driver.configuration.theme.background, .red)
    }

    func testFeedbackForm_whenScreenshotAndLocalConfigurationAreSet_shouldPreserveBoth() {
        let screenshot = UIImage()

        let sut = SentryUserFeedbackFormController(screenshot: screenshot) { config in
            config.configureForm = { $0.formTitle = "Screenshot title" }
        }

        XCTAssertIdentical(sut.screenshot, screenshot)
        XCTAssertEqual(sut.config.formConfig.formTitle, "Screenshot title")
    }

    func testFeedbackForm_whenLocalConfigurationSetAndFeedbackIntegrationNotConfigured_shouldUseDefaults() {
        clearTestState()

        let sut = SentryUserFeedbackFormController { config in
            config.configureForm = { $0.formTitle = "Default local title" }
        }

        XCTAssertEqual(sut.config.formConfig.formTitle, "Default local title")
    }

    func testShowForm_whenLocalConfigurationIsSet_shouldApplyToCurrentFormOnly() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.configureForm = { $0.formTitle = "Global title" }
        addCustomButton(to: viewController, configuration: config)
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        sut.showForm(from: viewController, screenshot: nil) { config in
            config.configureForm = { $0.formTitle = "Local title" }
            config.tags = ["source": "driver"]
        }
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertEqual(form.config.formConfig.formTitle, "Local title")
        XCTAssertEqual(try XCTUnwrap(form.config.tags?["source"] as? String), "driver")
        XCTAssertEqual(config.formConfig.formTitle, "Global title")

        withExtendedLifetime(window) { }
    }

    func testShowForm_whenNoPresenterAvailable_shouldNotPresentForm() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let application = TestSentryUIApplication()
        application.windows = []
        SentryDependencyContainer.sharedInstance().applicationOverride = application
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: SentryUserFeedbackConfiguration(),
            screenshotSource: makeScreenshotSource())

        sut.showForm()

        XCTAssertFalse(sut.displayingForm)
#endif
    }

    func testPresentingViewController_whenApplicationAndExternalDisplayWindows_shouldExcludeExternalDisplay() throws {
        let applicationViewController = TestPresentingViewController()
        let applicationWindow = TestWindowWithSceneRole(role: .windowApplication)
        applicationWindow.rootViewController = applicationViewController
        applicationWindow.makeKeyAndVisible()

        let externalDisplayViewController = TestPresentingViewController()
        let externalDisplayWindow = TestWindowWithSceneRole(role: Self.externalDisplayNonInteractiveSceneRole)
        externalDisplayWindow.rootViewController = externalDisplayViewController
        externalDisplayWindow.makeKeyAndVisible()

        let deprecatedExternalDisplayViewController = TestPresentingViewController()
        let deprecatedExternalDisplayWindow = TestWindowWithSceneRole(role: Self.deprecatedExternalDisplaySceneRole)
        deprecatedExternalDisplayWindow.rootViewController = deprecatedExternalDisplayViewController
        deprecatedExternalDisplayWindow.makeKeyAndVisible()

        let application = TestSentryUIApplication()
        application.windows = [externalDisplayWindow, deprecatedExternalDisplayWindow, applicationWindow]
        SentryDependencyContainer.sharedInstance().applicationOverride = application

        let presenter = try XCTUnwrap(SentryFeedbackFormPresenter.presentingViewController())

        XCTAssertIdentical(presenter, applicationViewController)

        withExtendedLifetime(applicationWindow) { }
        withExtendedLifetime(externalDisplayWindow) { }
        withExtendedLifetime(deprecatedExternalDisplayWindow) { }
    }

    func testPresentingViewController_whenOnlyExternalDisplayWindow_shouldReturnNil() {
        let externalDisplayViewController = TestPresentingViewController()
        let externalDisplayWindow = TestWindowWithSceneRole(role: Self.externalDisplayNonInteractiveSceneRole)
        externalDisplayWindow.rootViewController = externalDisplayViewController
        externalDisplayWindow.makeKeyAndVisible()

        let application = TestSentryUIApplication()
        application.windows = [externalDisplayWindow]
        SentryDependencyContainer.sharedInstance().applicationOverride = application

        XCTAssertNil(SentryFeedbackFormPresenter.presentingViewController())

        withExtendedLifetime(externalDisplayWindow) { }
    }

    func testPresentingViewController_whenOnlyDeprecatedExternalDisplayWindow_shouldReturnNil() {
        let externalDisplayViewController = TestPresentingViewController()
        let externalDisplayWindow = TestWindowWithSceneRole(role: Self.deprecatedExternalDisplaySceneRole)
        externalDisplayWindow.rootViewController = externalDisplayViewController
        externalDisplayWindow.makeKeyAndVisible()

        let application = TestSentryUIApplication()
        application.windows = [externalDisplayWindow]
        SentryDependencyContainer.sharedInstance().applicationOverride = application

        XCTAssertNil(SentryFeedbackFormPresenter.presentingViewController())

        withExtendedLifetime(externalDisplayWindow) { }
    }

    func testShakeGesture_whenNoWidgetOrCustomButton_shouldUseFallbackPresenter() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.useShakeGesture = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        useFallbackPresenter(viewController, in: window)

        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        _ = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertTrue(sut.displayingForm)

        withExtendedLifetime(window) { }
    }

    @available(*, deprecated, message: "Testing deprecated widget configuration")
    func testScreenshotTrigger_whenWidgetAutoInjectionDisabled_shouldUseFallbackPresenter() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let screenshot = UIImage()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.showFormForScreenshots = true
        config.configureWidget = { widget in
            widget.autoInject = false
        }
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: TestScreenshotSource(screenshots: [screenshot]))
        useFallbackPresenter(viewController, in: window)

        NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertIdentical(form.screenshot, screenshot)
        XCTAssertNil(widgetHost(for: sut))

        withExtendedLifetime(window) { }
#endif
    }

    func testShowForm_whenConfigurationBuildersAreSet_shouldNotApplyBuildersAgain() throws {
        let window = makeWindow()
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
        let window = makeWindow()
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

    func testShowForm_whenPresenterDoesNotShowForm_shouldKeepWidgetVisible() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            windowFactory: mockWindowFactory)
        sut.showWidget()
        let widgetHost = try XCTUnwrap(widgetHost(for: sut))
        let presenter = DroppingPresentingViewController()

        XCTAssertTrue(widgetHost.isWidgetVisible)

        sut.showForm(from: presenter, screenshot: nil)

        XCTAssertEqual(presenter.presentCallCount, 1)
        XCTAssertTrue(widgetHost.isWidgetVisible)
#endif
    }

    func testPresentationControllerDidDismiss_whenFormWasPresented_shouldClearActiveForm() throws {
        let window = makeWindow()
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
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            windowFactory: mockWindowFactory)
        sut.showWidget()
        let widgetHost = try XCTUnwrap(widgetHost(for: sut))

        XCTAssertTrue(widgetHost.isWidgetVisible)
        sut.showForm()

        let form = try XCTUnwrap(widgetHost.presentedViewController as? SentryUserFeedbackFormController)
        form.beginAppearanceTransition(true, animated: false)
        XCTAssertFalse(widgetHost.isWidgetVisible)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: widgetHost
        )

        form.endAppearanceTransition()
        form.presentationControllerDidDismiss(presentationController)

        XCTAssertTrue(widgetHost.isWidgetVisible)
#endif
    }

    func testShowForm_whenWidgetWasHidden_shouldKeepWidgetHiddenAfterFormCloses() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            windowFactory: mockWindowFactory)
        sut.showWidget()
        sut.hideWidget()
        let widgetHost = try XCTUnwrap(widgetHost(for: sut))

        XCTAssertFalse(widgetHost.isWidgetVisible)
        sut.showForm()
        XCTAssertFalse(widgetHost.isWidgetVisible)

        let form = try XCTUnwrap(widgetHost.presentedViewController as? SentryUserFeedbackFormController)
        form.beginAppearanceTransition(true, animated: false)
        XCTAssertFalse(widgetHost.isWidgetVisible)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: widgetHost
        )

        form.endAppearanceTransition()
        form.presentationControllerDidDismiss(presentationController)

        XCTAssertFalse(widgetHost.isWidgetVisible)
#endif
    }

    func testFeedbackFormController_whenPresentedDirectly_shouldHideWidgetUntilFormCloses() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let integration = try installFeedbackIntegration {
            $0.animations = false
        }
        integration.driver.showWidget()
        let widgetHost = try XCTUnwrap(widgetHost(for: integration.driver))
        let sut = SentryUserFeedbackFormController()

        XCTAssertTrue(widgetHost.isWidgetVisible)

        sut.beginAppearanceTransition(true, animated: false)
        XCTAssertFalse(widgetHost.isWidgetVisible)
        sut.endAppearanceTransition()

        let presentationController = UIPresentationController(
            presentedViewController: sut,
            presenting: nil
        )
        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertTrue(widgetHost.isWidgetVisible)
#endif
    }

    func testFeedbackFormController_whenWidgetWasHiddenBeforeDirectPresentation_shouldKeepWidgetHiddenAfterFormCloses() throws {
#if SDK_V10
        throw XCTSkip("Widget is not available in V10")
#else
        let integration = try installFeedbackIntegration {
            $0.animations = false
        }
        integration.driver.showWidget()
        integration.driver.hideWidget()
        let widgetHost = try XCTUnwrap(widgetHost(for: integration.driver))
        let sut = SentryUserFeedbackFormController()

        XCTAssertFalse(widgetHost.isWidgetVisible)

        sut.beginAppearanceTransition(true, animated: false)
        XCTAssertFalse(widgetHost.isWidgetVisible)
        sut.endAppearanceTransition()

        let presentationController = UIPresentationController(
            presentedViewController: sut,
            presenting: nil
        )
        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertFalse(widgetHost.isWidgetVisible)
#endif
    }

    // MARK: - Helpers

    private func installFeedbackIntegration(
        configure: @escaping (SentryUserFeedbackConfiguration) -> Void = { _ in }
    ) throws -> UserFeedbackIntegration<SentryDependencyContainer> {
        let options = Options()
        options.configureUserFeedback = configure
        SentrySDK.setStart(with: options)
        SentryDependencyContainer.sharedInstance().windowFactoryOverride = mockWindowFactory
        let integration = try XCTUnwrap(UserFeedbackIntegration<SentryDependencyContainer>(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()))
        SentrySDKInternal.currentHub().addInstalledIntegration(
            integration,
            name: UserFeedbackIntegration<SentryDependencyContainer>.name)
        return integration
    }

    #if !SDK_V10
    private func widgetHost(for driver: SentryUserFeedbackIntegrationDriver) -> SentryUserFeedbackWidget.RootViewController? {
        let widget = Mirror(reflecting: driver)
            .children
            .first { $0.label == "widget" }?
            .value as? SentryUserFeedbackWidget
        return widget?.rootVC
    }
    #endif

    private func addCustomButton(to viewController: UIViewController, configuration: SentryUserFeedbackConfiguration) {
        #if !SDK_V10
        let customButton = UIButton()
        configuration._customButton = customButton
        viewController.view.addSubview(customButton)
        #endif
    }

    private func useFallbackPresenter(_ viewController: UIViewController, in window: UIWindow) {
        window.rootViewController = viewController
        let application = TestSentryUIApplication()
        application.windows = [window]
        SentryDependencyContainer.sharedInstance().applicationOverride = application
    }

    private static var externalDisplayNonInteractiveSceneRole: UISceneSession.Role {
        if #available(iOS 16.0, *) {
            return .windowExternalDisplayNonInteractive
        }
        return UISceneSession.Role(rawValue: "UIWindowSceneSessionRoleExternalDisplayNonInteractive")
    }

    private static let deprecatedExternalDisplaySceneRole = UISceneSession.Role(
        rawValue: "UIWindowSceneSessionRoleExternalDisplay"
    )

    private final class TestScreenshotSource: SentryScreenshotSource {
        private let screenshots: [UIImage]

        init(screenshots: [UIImage]) {
            self.screenshots = screenshots
            super.init(photographer: SentryViewPhotographer(
                renderer: SentryDefaultViewRenderer(),
                redactOptions: Options().screenshot,
                enableMaskRendererV2: false))
        }

        override func appScreenshots() -> [UIImage] {
            return screenshots
        }
    }

    private final class TestWindowWithSceneRole: UIWindow {
        private var mockWindowScene: UIWindowScene?

        init(role: UISceneSession.Role) {
            let mockWindowScene = MockUIWindowScene(sessionRole: role)
            self.mockWindowScene = mockWindowScene
            super.init(windowScene: mockWindowScene)
        }

        required init?(coder: NSCoder) {
            return nil
        }

        override var windowScene: UIWindowScene? {
            get { mockWindowScene }
            set { mockWindowScene = newValue }
        }
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

    private final class DroppingPresentingViewController: UIViewController {
        private(set) var presentCallCount = 0

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated _: Bool,
            completion: (() -> Void)? = nil
        ) {
            presentCallCount += 1
        }
    }
}

#endif
