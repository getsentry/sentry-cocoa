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
final class SentryUserFeedbackIntegrationDriver: NSObject, SentryUserFeedbackWidgetDelegate {
    let configuration: SentryUserFeedbackConfiguration
    private var widget: SentryUserFeedbackWidget?
    private var shouldRestoreWidgetAfterFormDismissal = false
    private var didOpenForm = false
    private weak var installedPresenter: SentryFeedbackFormPresenter?
    private var activePresenter: SentryFeedbackFormPresenter?
    fileprivate let callback: (SentryFeedback) -> Void
    let screenshotSource: SentryScreenshotSource

    init(configuration: SentryUserFeedbackConfiguration, screenshotSource: SentryScreenshotSource, callback: @escaping (SentryFeedback) -> Void) {
        self.configuration = configuration
        self.callback = callback
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
        configuration.customButton?.removeTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        SentryShakeDetector.disable()
        NotificationCenter.default.removeObserver(self)
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

    var isDisplayingForm: Bool {
        activePresenter != nil
    }

    func formDidOpen() {
        guard isDisplayingForm, !didOpenForm else {
            return
        }

        didOpenForm = true
        configuration.onFormOpen?()
    }

    func formDidFinish(feedback: SentryFeedback?) {
        if let feedback = feedback {
            callback(feedback)
        }
    }

    func setFeedbackFormPresenter(_ presenter: SentryFeedbackFormPresenter?) {
        installedPresenter = presenter
    }

    func removeFeedbackFormPresenter(_ presenter: SentryFeedbackFormPresenter) {
        guard installedPresenter === presenter else { return }
        installedPresenter = nil
    }

    @discardableResult
    func presentForm(screenshot: UIImage? = nil) -> Bool {
        if let installedPresenter = installedPresenter {
            return present(using: installedPresenter, screenshot: screenshot)
        }

        return present(using: makeAutomaticUIKitPresenter(), screenshot: screenshot)
    }

    @discardableResult
    func presentForm(in windowScene: UIWindowScene, screenshot: UIImage?) -> Bool {
        return present(
            using: makeUIKitPresenter { [weak windowScene] in
                windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            },
            screenshot: screenshot
        )
    }

    @discardableResult
    func presentForm(from viewController: UIViewController, screenshot: UIImage?) -> Bool {
        return present(
            using: makeUIKitPresenter { [weak viewController] in
                viewController
            },
            screenshot: screenshot
        )
    }

    @objc func showForm(sender: UIButton) {
        presentForm(screenshot: nil)
    }

    func showFeedbackForm() {
        presentForm(screenshot: nil)
    }
}

// MARK: SentryUserFeedbackFormDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackFormDelegate {
    func didAppear() {
        formDidOpen()
    }

    func finished(with feedback: SentryFeedback?) {
        formDidFinish(feedback: feedback)
        activePresenter?.dismiss()
    }
}

// MARK: SentryFeedbackFormPresenterDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: SentryFeedbackFormPresenterDelegate {
    func feedbackFormPresenterDidDismiss(_ presenter: SentryFeedbackFormPresenter) {
        guard activePresenter === presenter else { return }

        presenter.delegate = nil
        activePresenter = nil
        restoreWidgetForPresentedFormIfNeeded()

        if didOpenForm {
            didOpenForm = false
            configuration.onFormClose?()
        }
    }
}

// MARK: Presentation
@available(iOSApplicationExtension, unavailable)
private extension SentryUserFeedbackIntegrationDriver {
    func hideWidgetForPresentedForm() {
        guard let widget = widget else { return }
        shouldRestoreWidgetAfterFormDismissal = widget.isVisible
        hideWidget()
    }

    func restoreWidgetForPresentedFormIfNeeded() {
        guard shouldRestoreWidgetAfterFormDismissal else { return }
        shouldRestoreWidgetAfterFormDismissal = false
        widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
    }

    func present(
        using presenter: SentryFeedbackFormPresenter,
        screenshot: UIImage?
    ) -> Bool {
        guard activePresenter == nil else {
            SentrySDKLog.debug("Cannot show feedback form — feedback form is already displayed")
            return false
        }

        hideWidgetForPresentedForm()
        didOpenForm = false
        presenter.delegate = self

        guard presenter.present(screenshot: screenshot) else {
            restoreWidgetForPresentedFormIfNeeded()
            presenter.delegate = nil
            return false
        }

        activePresenter = presenter
        return true
    }

}

// MARK: Host Resolving
@available(iOSApplicationExtension, unavailable)
private extension SentryUserFeedbackIntegrationDriver {
    // Host preference order for automatic presentation:
    // custom button, widget, foreground key-window root, then first key-window root fallback.
    func makeAutomaticUIKitPresenter() -> SentryFeedbackFormPresenter {
        return makeUIKitPresenter { [weak self] in
            guard let self else { return nil }
            
            if let customButtonController {
                return customButtonController
            }

            if let widgetHost = widget?.rootVC {
                return widgetHost
            }

            return firstAvailableWindowHost
        }
    }

    func makeUIKitPresenter(presentingViewControllerProvider: @escaping SentryFeedbackFormPresentingViewControllerProvider) -> SentryFeedbackFormPresenter {
        return SentryUIKitFeedbackFormPresenter(
            presentingViewControllerProvider: presentingViewControllerProvider,
            configuration: configuration,
            formDelegate: self
        )
    }
    
    /// In order to present our form, we need a `UIViewController` on which to call `presentViewController`. This computed var helps to find one. While we may know the owning UIVC for our own widget button, we won't know the makeup of the view/controller hierarchy if a customer uses their own button with `SentryUserFeedbackConfiguration.customButton`.
    /// - returns: The innermost `UIViewController` instance managing the receiving view.
    var customButtonController: UIViewController? {
        var responder = configuration.customButton?.next
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

    /// Finds a root view controller suitable for automatic presentation by preferring the key
    /// window in a foreground-active scene and falling back to the first key-window root found.
    var firstAvailableWindowHost: UIViewController? {
        var fallbackPresenter: UIViewController?

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                let presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                continue
            }

            if windowScene.activationState == .foregroundActive {
                return presenter
            }

            if fallbackPresenter == nil {
                fallbackPresenter = presenter
            }
        }

        return fallbackPresenter
    }
}

// MARK: Private
@available(iOSApplicationExtension, unavailable)
private extension SentryUserFeedbackIntegrationDriver {
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
        presentForm(screenshot: nil)
    }

    @objc func userCapturedScreenshot() {
        stopObservingScreenshots()
        presentForm(screenshot: screenshotSource.appScreenshots().first)
    }

    func stopObservingScreenshots() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
