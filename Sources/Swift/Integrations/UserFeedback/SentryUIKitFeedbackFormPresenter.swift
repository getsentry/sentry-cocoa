// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

typealias SentryFeedbackFormHostProvider = () -> UIViewController?

@available(iOSApplicationExtension, unavailable)
final class SentryUIKitFeedbackFormPresenter: NSObject, SentryFeedbackFormPresenter {
    weak var delegate: SentryFeedbackFormPresenterDelegate?

    private let hostProvider: SentryFeedbackFormHostProvider
    private let configuration: SentryUserFeedbackConfiguration
    private weak var formDelegate: SentryUserFeedbackFormDelegate?
    private weak var form: SentryUserFeedbackFormController?

    init(
        hostProvider: @escaping SentryFeedbackFormHostProvider,
        configuration: SentryUserFeedbackConfiguration,
        formDelegate: SentryUserFeedbackFormDelegate
    ) {
        self.hostProvider = hostProvider
        self.configuration = configuration
        self.formDelegate = formDelegate
    }

    @discardableResult
    func present(screenshot: UIImage?) -> Bool {
        guard let controller = hostProvider() else {
            SentrySDKLog.debug("Cannot show feedback form — no presenter available")
            return false
        }

        guard canPresentForm(from: controller) else {
            return false
        }

        let form = SentryUserFeedbackFormController(
            config: configuration,
            delegate: formDelegate,
            screenshot: screenshot
        )
        form.presentationController?.delegate = self
        self.form = form
        controller.present(form, animated: configuration.animations)
        return true
    }

    func dismiss() {
        guard let form = form else {
            notifyDismissed()
            return
        }
        form.dismiss(animated: configuration.animations) { [weak self] in
            self?.notifyDismissed()
        }
    }
}

// Private
@available(iOSApplicationExtension, unavailable)
fileprivate extension SentryUIKitFeedbackFormPresenter {
    private func canPresentForm(from viewController: UIViewController) -> Bool {
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

    func notifyDismissed() {
        form = nil
        delegate?.feedbackFormPresenterDidDismiss(self)
    }
}

@available(iOSApplicationExtension, unavailable)
extension SentryUIKitFeedbackFormPresenter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        notifyDismissed()
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
