// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The default method to show the feedback form is via a floating widget placed in the bottom trailing corner of the screen. See the configuration classes for alternative options.
 */
@available(iOSApplicationExtension, unavailable)
final class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private var widget: SentryUserFeedbackWidget?
    private weak var activeForm: SentryUserFeedbackFormController?
    let screenshotSource: SentryScreenshotSource
    weak var customButton: UIButton?

    init(configuration: SentryUserFeedbackConfiguration, screenshotSource: SentryScreenshotSource) {
        self.configuration = configuration
        self.screenshotSource = screenshotSource
        super.init()

        if let uiFormConfigBuilder = configuration.configureForm {
            uiFormConfigBuilder(configuration.formConfig)
        }
        if let themeOverrideBuilder = configuration.configureTheme {
            themeOverrideBuilder(configuration.theme)
        }
        if let darkThemeOverrideBuilder = configuration.configureDarkTheme {
            darkThemeOverrideBuilder(configuration.darkTheme)
        }

        if let customButton = configuration.customButton {
            self.customButton = customButton
            customButton.addTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        } else if let widgetConfigBuilder = configuration.configureWidget {
            widgetConfigBuilder(configuration.widgetConfig)
            validate(configuration.widgetConfig)

            /*
             * We cannot currently automatically inject a widget into a SwiftUI application, because at the recommended time to start the Sentry SDK (SwiftUIApp.init) there is nowhere to put a UIWindow overlay. SwiftUI apps must currently declare a UIApplicationDelegateAdaptor that returns a UISceneConfiguration, which we can then extract a connected UIScene from into which we can inject a UIWindow.
             *
             * At the time this integration is being installed, if there is no UIApplicationDelegate and no connected UIScene, it is very likely we are in a SwiftUI app, but it's possible we could instead be in a UIKit app that has some nonstandard launch procedure or doesn't call SentrySDK.start in a place we expect/recommend, in which case they will need to manually display the widget when they're ready by calling SentrySDK.feedback.showWidget.
             */
            if UIApplication.shared.connectedScenes.isEmpty && UIApplication.shared.delegate == nil {
                observeShakeGesture()
                return
            }

            if configuration.widgetConfig.autoInject {
                widget = SentryUserFeedbackWidget(config: configuration, delegate: self)
            }
        }

        observeScreenshots()
        observeShakeGesture()
    }

    deinit {
        customButton?.removeTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        SentryShakeDetector.disable()
        NotificationCenter.default.removeObserver(self)
    }

    func uninstall() {
        let form = activeForm
        activeForm = nil
        form?.dismiss(animated: configuration.animations)
    }

    func showWidget() {
        if widget == nil {
            widget = SentryUserFeedbackWidget(config: configuration, delegate: self)
        }

        widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
    }

    func hideWidget() {
        widget?.rootVC.setWidget(visible: false, animated: configuration.animations)
    }

    @objc func showForm(sender: UIButton) {
        showForm(screenshot: nil)
    }

    var isDisplayingForm: Bool {
        return activeForm != nil
    }
}

// MARK: SentryUserFeedbackWidgetDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackWidgetDelegate {
    func showForm() {
        showForm(screenshot: nil)
    }
}

// MARK: UIAdaptivePresentationControllerDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === activeForm else { return }
        activeForm = nil
    }
}

// MARK: Private
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver {
    @discardableResult
    func showForm(screenshot: UIImage? = nil) -> Bool {
        guard let presenter = presenter else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return false
        }

        return present(from: presenter, screenshot: screenshot)
    }

    @discardableResult
    func present(from presenter: UIViewController, screenshot: UIImage?) -> Bool {
        guard activeForm == nil else {
            SentrySDKLog.debug("Cannot show feedback form — feedback form is already displayed")
            return false
        }

        guard canPresentForm(from: presenter) else {
            return false
        }

        let form = SentryUserFeedbackFormController(preparedConfig: configuration, image: screenshot)
        activeForm = form
        presenter.present(form, animated: configuration.animations)
        form.presentationController?.delegate = self
        return true
    }

    private func canPresentForm(from viewController: UIViewController) -> Bool {
        guard !(viewController is SentryUserFeedbackFormController) else {
            SentrySDKLog.debug("Cannot show feedback form — feedback form is already displayed")
            return false
        }

        guard viewController.viewIfLoaded?.window != nil else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is not attached to a window")
            return false
        }

        guard viewController.presentedViewController == nil else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is already presenting another view controller")
            return false
        }

        guard !viewController.isBeingPresented && !viewController.isBeingDismissed else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is transitioning")
            return false
        }

        return true
    }

    func validate(_ config: SentryUserFeedbackWidgetConfiguration) {
        let noOpposingHorizontals = config.location.contains(.trailing) && !config.location.contains(.leading)
        || !config.location.contains(.trailing) && config.location.contains(.leading)
        let noOpposingVerticals = config.location.contains(.top) && !config.location.contains(.bottom)
        || !config.location.contains(.top) && config.location.contains(.bottom)
        let atLeastOneLocation = config.location.contains(.trailing)
        || config.location.contains(.leading)
        || config.location.contains(.top)
        || config.location.contains(.bottom)
        let notAll = !config.location.contains(.all)
        let valid = noOpposingVerticals && noOpposingHorizontals && atLeastOneLocation && notAll
#if DEBUG
        assert(valid, "Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
#endif // DEBUG
        if !valid {
            SentrySDKLog.warning("Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
        }
    }

    func observeScreenshots() {
        if configuration.showFormForScreenshots {
            NotificationCenter.default.addObserver(self, selector: #selector(userCapturedScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
    }

    func observeShakeGesture() {
        guard configuration.useShakeGesture else {
            SentrySDKLog.debug("Shake gesture detection is disabled in configuration")
            return
        }
        SentryShakeDetector.enable()
        NotificationCenter.default.addObserver(self, selector: #selector(handleShakeGesture), name: .SentryShakeDetected, object: nil)
    }

    @objc func handleShakeGesture() {
        guard !isDisplayingForm else {
            SentrySDKLog.debug("Shake gesture ignored — feedback form is already displayed")
            return
        }
        showForm(screenshot: nil)
    }

    @objc func userCapturedScreenshot() {
        stopObservingScreenshots()
        showForm(screenshot: screenshotSource.appScreenshots().first)
    }

    func stopObservingScreenshots() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }

    var presenter: UIViewController? {
        if let customButton = configuration.customButton {
            return presentingViewController(from: customButton.controller)
        }

        if let widgetHost = widget?.rootVC {
            return widgetHost
        }

        return fallbackPresenter
    }

    /// Finds a view controller suitable for automatic presentation by preferring the key
    /// window in a foreground-active scene and falling back to the first key-window found.
    private var fallbackPresenter: UIViewController? {
        var firstKeyWindowPresenter: UIViewController?

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                let presenter = keyWindowPresenter(in: windowScene) else {
                continue
            }

            if windowScene.activationState == .foregroundActive {
                return presenter
            }

            if firstKeyWindowPresenter == nil {
                firstKeyWindowPresenter = presenter
            }
        }

        return firstKeyWindowPresenter
    }

    /// Finds the view controller that should present the feedback form for the key window in
    /// the given scene. If the root view controller is already presenting another controller,
    /// this returns the top-most presented controller that is not currently being dismissed.
    private func keyWindowPresenter(in windowScene: UIWindowScene) -> UIViewController? {
        let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        return presentingViewController(from: rootViewController)
    }

    /// Resolves the view controller best suited for presenting the feedback form by walking
    /// through any view controllers already presented by the starting view controller.
    private func presentingViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }

        if let presentedViewController = viewController.presentedViewController,
            !presentedViewController.isBeingDismissed {
            return presentingViewController(from: presentedViewController)
        }

        return viewController
    }
}

extension UIView {
    /// In order to present our form, we need a `UIViewController` on which to call `presentViewController`. This computed var helps to find one. While we may know the owning UIVC for our own widget button, we won't know the makeup of the view/controller hierarchy if a customer uses their own button with `SentryUserFeedbackConfiguration.customButton`.
    /// - returns: The innermost `UIViewController` instance managing the receiving view.
    var controller: UIViewController? {
        var responder = next
        while responder != nil {
            guard let resolvedResponder = responder else { break }
            let klass = type(of: resolvedResponder)
            guard klass.isSubclass(of: UIViewController.self) else {
                responder = resolvedResponder.next
                continue
            }
            return resolvedResponder as? UIViewController
        }
        return nil
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
