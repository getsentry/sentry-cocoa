// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The managed widget is deprecated and will be removed in v10; prefer presenting the form from your own UI.
 */
@available(iOSApplicationExtension, unavailable)
final class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private weak var activeForm: SentryUserFeedbackFormController?
    let screenshotSource: SentryScreenshotSource
    let windowFactory: SentryUserFeedbackWindowFactory
    #if !SDK_V10
    private var widget: SentryUserFeedbackWidget?
    private var shouldRestoreWidgetOnFormClose = false
    weak var customButton: UIButton?
    #endif

    init(configuration: SentryUserFeedbackConfiguration, screenshotSource: SentryScreenshotSource, windowFactory: @escaping SentryUserFeedbackWindowFactory = SentryUserFeedbackWidget.defaultWindowFactory) {
        self.configuration = configuration
        self.screenshotSource = screenshotSource
        self.windowFactory = windowFactory
        super.init()

        configuration.applyConfigurationBuilders()

        #if !SDK_V10
        if let customButton = configuration.customButton {
            self.customButton = customButton
            customButton.addTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        } else if let widgetConfigBuilder = configuration.configureWidget {
            widgetConfigBuilder(configuration.widgetConfig)
            validate(configuration.widgetConfig)

            /*
             * We cannot currently automatically inject a widget into a SwiftUI application, because at the recommended time to start the Sentry SDK (SwiftUIApp.init) there is nowhere to put a UIWindow overlay. SwiftUI apps must currently declare a UIApplicationDelegateAdaptor that returns a UISceneConfiguration, which we can then extract a connected UIScene from into which we can inject a UIWindow.
             *
             * At the time this integration is being installed, if there is no UIApplicationDelegate and no connected UIScene, it is very likely we are in a SwiftUI app, but it's possible we could instead be in a UIKit app that has some nonstandard launch procedure or doesn't call SentrySDK.start in a place we expect/recommend, in which case they will need to manually display the widget when they're ready by calling SentrySDK.feedback.showWidget. The managed widget is deprecated; prefer presenting the feedback form from your own UI using SentrySDK.feedback.show(), SentrySDK.FeedbackForm, or sentryFeedback(isPresented:).
             */
            if UIApplication.shared.connectedScenes.isEmpty && UIApplication.shared.delegate == nil {
                observeScreenshots()
                observeShakeGesture()
                return
            }

            if configuration.widgetConfig.autoInject {
                widget = SentryUserFeedbackWidget(config: configuration, delegate: self, windowFactory: windowFactory)
            }
        }
        #endif

        observeScreenshots()
        observeShakeGesture()
    }

    deinit {
        #if !SDK_V10
        customButton?.removeTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        #endif
        SentryShakeDetector.disable()
        NotificationCenter.default.removeObserver(self)
    }

    #if !SDK_V10
    func showWidget() {
        if widget == nil {
            widget = SentryUserFeedbackWidget(config: configuration, delegate: self, windowFactory: windowFactory)
        }

        widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
    }

    func hideWidget() {
        widget?.rootVC.setWidget(visible: false, animated: configuration.animations)
    }
    #endif

    @objc func showForm(sender: UIButton) {
        showForm(screenshot: nil)
    }

    var displayingForm: Bool {
        return activeForm != nil
    }

    #if !SDK_V10
    private func hideWidgetForFormPresentation(_ form: SentryUserFeedbackFormController) {
        shouldRestoreWidgetOnFormClose = widget?.rootVC.isWidgetVisible == true
        widget?.rootVC.setWidget(visible: false, animated: form.config.animations)
    }
    #endif
}

#if !SDK_V10
// MARK: SentryUserFeedbackWidgetDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackWidgetDelegate {
    func showForm() {
        showForm(screenshot: nil)
    }
}
#endif

// MARK: SentryUserFeedbackFormDelegate
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackFormDelegate {
    func userFeedbackFormWillOpen(_ form: SentryUserFeedbackFormController) {
        if let activeForm = activeForm {
            guard activeForm === form else {
                SentrySDKLog.debug("Cannot show feedback form — feedback form is already displayed")
                return
            }
        } else {
            activeForm = form
        }

        #if !SDK_V10
        hideWidgetForFormPresentation(form)
        #endif
    }

    func userFeedbackFormDidClose(_ form: SentryUserFeedbackFormController) {
        guard activeForm === form else { return }

        activeForm = nil
        #if !SDK_V10
        let shouldRestoreWidget = shouldRestoreWidgetOnFormClose
        shouldRestoreWidgetOnFormClose = false
        if shouldRestoreWidget {
            widget?.rootVC.setWidget(visible: true, animated: form.config.animations)
        }
        #endif
    }
}

// MARK: Internal
@available(iOSApplicationExtension, unavailable)
extension SentryUserFeedbackIntegrationDriver {
    func showForm(
        from presenter: UIViewController,
        screenshot: UIImage?,
        configure: SentryUserFeedbackConfigurationCallback? = nil
    ) {
        guard activeForm == nil else {
            SentrySDKLog.debug("Cannot show feedback form — feedback form is already displayed")
            return
        }

        let formConfig = configuration.configurationForPresentation(configure: configure)
        let form = SentryUserFeedbackFormController(preparedConfig: formConfig, screenshot: screenshot)
        form.delegate = self
        activeForm = form
        presenter.present(form, animated: formConfig.animations)
    }
}

// MARK: Private
@available(iOSApplicationExtension, unavailable)
private extension SentryUserFeedbackIntegrationDriver {
    func showForm(screenshot: UIImage? = nil) {
        guard let presenter = presenter else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return
        }

        showForm(from: presenter, screenshot: screenshot)
    }

    #if !SDK_V10
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
    #endif

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
        guard !displayingForm else {
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
        #if !SDK_V10
        if let customButton = configuration.customButton?.controller {
            return customButton
        }

        if let widgetRootViewController = widget?.rootVC {
            return widgetRootViewController
        }
        #endif

        return SentryFeedbackFormPresenter.presentingViewController()
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
