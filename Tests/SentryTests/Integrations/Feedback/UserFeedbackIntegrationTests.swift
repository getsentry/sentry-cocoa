// swiftlint:disable file_length
@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import _SentryPrivate
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

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }

    private struct TestDependencies: UserFeedbackIntegrationProvider {
        let screenshotSource: SentryScreenshotSource?
    }

    private func makeScreenshotSource() -> SentryScreenshotSource {
        let viewRenderer = SentryDefaultViewRenderer()
        let photographer = SentryViewPhotographer(
            renderer: viewRenderer,
            redactOptions: TestRedactOptions(),
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
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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

    func testSetShakeGestureEnabled_whenEnabledAtRuntime_shouldPresentFormOnShake() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.useShakeGesture = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        useFallbackPresenter(viewController, in: window)

        // Not observing yet — a shake should be ignored.
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)
        XCTAssertFalse(sut.displayingForm)

        sut.setShakeGestureEnabled(true)
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        _ = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertTrue(sut.displayingForm)
        XCTAssertTrue(config.useShakeGesture)

        withExtendedLifetime(window) { }
    }

    func testSetShakeGestureEnabled_whenDisabledAtRuntime_shouldNotPresentFormOnShake() {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.useShakeGesture = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        useFallbackPresenter(viewController, in: window)

        sut.setShakeGestureEnabled(false)
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        XCTAssertFalse(sut.displayingForm)
        XCTAssertEqual(viewController.presentCallCount, 0)
        XCTAssertFalse(config.useShakeGesture)

        withExtendedLifetime(window) { }
    }

    func testSetShakeGestureEnabled_whenEnabledTwice_shouldRegisterObserverOnce() {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let config = SentryUserFeedbackConfiguration()
        config.useShakeGesture = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            notificationCenter: notificationCenter)

        sut.setShakeGestureEnabled(true)
        sut.setShakeGestureEnabled(true)

        let shakeObservers = notificationCenter.addObserverWithObjectInvocations.invocations
            .filter { $0.name == .SentryShakeDetected }
        XCTAssertEqual(shakeObservers.count, 1)
    }

    func testSetShakeGestureEnabled_whenDisabledAfterInit_shouldRemoveObserver() throws {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let config = SentryUserFeedbackConfiguration()
        config.useShakeGesture = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            notificationCenter: notificationCenter)

        sut.setShakeGestureEnabled(false)

        let removal = try XCTUnwrap(notificationCenter.removeObserverWithNameAndObjectInvocations
            .invocations.first { $0.name == .SentryShakeDetected })
        XCTAssertEqual(removal.name, .SentryShakeDetected)
    }

    func testSetShakeGestureEnabled_whenReEnabledAfterDisable_shouldPresentFormOnShake() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.useShakeGesture = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        useFallbackPresenter(viewController, in: window)

        sut.setShakeGestureEnabled(false)
        sut.setShakeGestureEnabled(true)
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        _ = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertTrue(sut.displayingForm)
        XCTAssertTrue(config.useShakeGesture)

        withExtendedLifetime(window) { }
    }

    func testSetShakeGestureEnabled_whenDisabled_shouldKeepScreenshotObserver() throws {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let config = SentryUserFeedbackConfiguration()
        config.showFormForScreenshots = true
        config.useShakeGesture = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            notificationCenter: notificationCenter)
        XCTAssertEqual(notificationCenter.observerCount, 2)

        sut.setShakeGestureEnabled(false)

        // Only the shake observer is removed; the screenshot observer survives.
        let removals = notificationCenter.removeObserverWithNameAndObjectInvocations.invocations
        XCTAssertEqual(removals.count, 1)
        XCTAssertEqual(removals.first?.name, .SentryShakeDetected)
        XCTAssertEqual(notificationCenter.observerCount, 1)

        withExtendedLifetime(sut) { }
    }

    func testSetShakeGestureEnabled_whenDisabledWhileNotObserving_shouldBeNoOp() {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let config = SentryUserFeedbackConfiguration()
        config.useShakeGesture = false
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            notificationCenter: notificationCenter)

        sut.setShakeGestureEnabled(false)

        XCTAssertTrue(notificationCenter.removeObserverWithNameAndObjectInvocations.invocations.isEmpty)
        XCTAssertFalse(config.useShakeGesture)

        withExtendedLifetime(sut) { }
    }

    func testFeedbackAPI_enableOnShake_whenConfigured_shouldPresentFormOnShake() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let integration = try installFeedbackIntegration { $0.animations = false }
        useFallbackPresenter(viewController, in: window)

        // Not observing yet (useShakeGesture defaults to false) — a shake is ignored.
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)
        XCTAssertFalse(integration.driver.displayingForm)

        SentrySDK.feedback.enableOnShake()
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        _ = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertTrue(integration.driver.displayingForm)

        withExtendedLifetime(window) { }
    }

    func testFeedbackAPI_disableOnShake_whenConfigured_shouldSuppressFormOnShake() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let integration = try installFeedbackIntegration {
            $0.animations = false
            $0.useShakeGesture = true
        }
        useFallbackPresenter(viewController, in: window)

        SentrySDK.feedback.disableOnShake()
        NotificationCenter.default.post(name: .SentryShakeDetected, object: nil)

        XCTAssertFalse(integration.driver.displayingForm)
        XCTAssertEqual(viewController.presentCallCount, 0)

        withExtendedLifetime(window) { }
    }

    func testFeedbackAPI_onShake_whenFeedbackNotConfigured_shouldNotCrash() {
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()

        SentrySDK.feedback.enableOnShake()
        SentrySDK.feedback.disableOnShake()
    }

    func testScreenshotTrigger_whenRetinaImageRendered_shouldPreserveResolution() throws {
        for enableMaskRendererV2 in [false, true] {
            for scale: CGFloat in [2, 3] {
                // -- Arrange --
                let size = CGSize(width: 30, height: 20)
                let window = makeWindow()
                window.frame = CGRect(origin: .zero, size: size)
                let viewController = TestPresentingViewController()
                useFallbackPresenter(viewController, in: window)
                let renderer = TestSentryViewRenderer()
                let format = UIGraphicsImageRendererFormat()
                format.scale = scale
                renderer.mockedReturnValue = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor.red.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
                let source = SentryScreenshotSource(photographer: SentryViewPhotographer(
                    renderer: renderer,
                    redactOptions: SentryRedactDefaultOptions(),
                    enableMaskRendererV2: enableMaskRendererV2))
                let config = SentryUserFeedbackConfiguration()
                config.animations = false
                config.showFormForScreenshots = true
                let sut = SentryUserFeedbackIntegrationDriver(configuration: config, screenshotSource: source)

                // -- Act --
                NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

                // -- Assert --
                let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
                let screenshot = try XCTUnwrap(form.screenshot)
                XCTAssertEqual(screenshot.scale, scale)
                XCTAssertEqual(try XCTUnwrap(screenshot.cgImage).width, Int(size.width * scale))
                XCTAssertEqual(try XCTUnwrap(screenshot.cgImage).height, Int(size.height * scale))
                withExtendedLifetime((sut, window)) { }
            }
        }
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

    // Regression test for #7641: screenshots after dismissing the feedback form
    // should still trigger a new form presentation.
    func testScreenshotTrigger_presentsExactlyOncePerScreenshotAcrossDismissal() throws {
        let window = makeWindow()
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        config.showFormForScreenshots = true
        let sut = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource())
        useFallbackPresenter(viewController, in: window)

        NotificationCenter.default.post(
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        XCTAssertEqual(viewController.presentCallCount, 1)
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)

        NotificationCenter.default.post(
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        XCTAssertEqual(viewController.presentCallCount, 1)

        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: viewController
        )
        form.beginAppearanceTransition(true, animated: false)
        form.endAppearanceTransition()
        form.presentationControllerDidDismiss(presentationController)
        XCTAssertFalse(sut.displayingForm)

        NotificationCenter.default.post(
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        XCTAssertEqual(viewController.presentCallCount, 2)

        withExtendedLifetime(window) { }
    }

    func testDeinit_removesNotificationObservers() throws {
        let notificationCenter = TestNSNotificationCenterWrapper()
        let config = SentryUserFeedbackConfiguration()
        config.showFormForScreenshots = true
        config.useShakeGesture = true
        var sut: SentryUserFeedbackIntegrationDriver? = SentryUserFeedbackIntegrationDriver(
            configuration: config,
            screenshotSource: makeScreenshotSource(),
            notificationCenter: notificationCenter)

        XCTAssertNotNil(sut)
        let observedNames = notificationCenter.addObserverWithObjectInvocations.invocations.map { $0.name }
        XCTAssertTrue(observedNames.contains(UIApplication.userDidTakeScreenshotNotification))
        XCTAssertTrue(observedNames.contains(.SentryShakeDetected))
        XCTAssertEqual(notificationCenter.observerCount, 2)

        sut = nil

        XCTAssertEqual(notificationCenter.removeObserverWithNameAndObjectInvocations.count, 1)
        let removal = try XCTUnwrap(notificationCenter.removeObserverWithNameAndObjectInvocations.first)
        XCTAssertNil(removal.name)
        XCTAssertNil(removal.object)
    }

    // MARK: - Helpers

    private func installFeedbackIntegration(
        configure: @escaping (SentryUserFeedbackConfiguration) -> Void = { _ in }
    ) throws -> UserFeedbackIntegration<SentryDependencyContainer> {
        let options = Options()
        options.configureUserFeedback = configure
        SentrySDK.setStart(with: options)
        let integration = try XCTUnwrap(UserFeedbackIntegration<SentryDependencyContainer>(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()))
        SentrySDKInternal.currentHub().addInstalledIntegration(
            integration,
            name: UserFeedbackIntegration<SentryDependencyContainer>.name)
        return integration
    }

    private func addCustomButton(to viewController: UIViewController, configuration: SentryUserFeedbackConfiguration) {
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
                redactOptions: TestRedactOptions(),
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
// swiftlint:enable file_length
