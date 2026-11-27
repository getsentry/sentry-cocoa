// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import UIKit

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The managed widget is deprecated and will be removed in v10; prefer presenting the form from your own UI.
 */
@available(iOSApplicationExtension, unavailable)
final class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private weak var activeForm: SentryUserFeedbackFormController?
    private var isObservingShakeGesture = false
    let screenshotSource: SentryScreenshotSource
    private let notificationCenter: SentryNSNotificationCenterWrapper
    
    init(
        configuration: SentryUserFeedbackConfiguration,
        screenshotSource: SentryScreenshotSource,
        notificationCenter: SentryNSNotificationCenterWrapper = NotificationCenter.default
    ) {
        self.configuration = configuration
        self.screenshotSource = screenshotSource
        self.notificationCenter = notificationCenter
        super.init()

        configuration.applyConfigurationBuilders()

        observeScreenshots()
        observeShakeGesture()
    }

    deinit {
        SentryShakeDetector.disable()
        notificationCenter.removeObserver(self, name: nil, object: nil)
    }

    @objc func showForm(sender: UIButton) {
        showForm(screenshot: nil)
    }

    var displayingForm: Bool {
        return activeForm != nil
    }

}

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

    }

    func userFeedbackFormDidClose(_ form: SentryUserFeedbackFormController) {
        guard activeForm === form else { return }

        activeForm = nil
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

    /// Enables or disables shake-gesture-triggered feedback at runtime.
    ///
    /// This lets consumers toggle shake-to-report after `SentrySDK.start`, e.g. once an
    /// asynchronously fetched feature flag resolves. Repeated calls with the same value are no-ops.
    /// - Parameter enabled: `true` to start detecting shakes and presenting the feedback form;
    ///   `false` to stop.
    func setShakeGestureEnabled(_ enabled: Bool) {
        configuration.useShakeGesture = enabled
        if enabled {
            guard !isObservingShakeGesture else { return }
            isObservingShakeGesture = true
            SentryShakeDetector.enable()
            notificationCenter.addObserver(self, selector: #selector(handleShakeGesture), name: .SentryShakeDetected, object: nil)
        } else {
            guard isObservingShakeGesture else { return }
            isObservingShakeGesture = false
            SentryShakeDetector.disable()
            notificationCenter.removeObserver(self, name: .SentryShakeDetected, object: nil)
        }
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

    func observeScreenshots() {
        if configuration.showFormForScreenshots {
            notificationCenter.addObserver(self, selector: #selector(userCapturedScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
    }

    func observeShakeGesture() {
        guard configuration.useShakeGesture else {
            SentrySDKLog.debug("Shake gesture detection is disabled in configuration")
            return
        }
        setShakeGestureEnabled(true)
    }

    @objc func handleShakeGesture() {
        guard !displayingForm else {
            SentrySDKLog.debug("Shake gesture ignored — feedback form is already displayed")
            return
        }
        showForm(screenshot: nil)
    }

    @objc func userCapturedScreenshot() {
        guard !displayingForm else {
            SentrySDKLog.debug("Screenshot ignored — feedback form is already displayed")
            return
        }
        showForm(screenshot: screenshotSource.appScreenshots().first)
    }

    var presenter: UIViewController? {

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
