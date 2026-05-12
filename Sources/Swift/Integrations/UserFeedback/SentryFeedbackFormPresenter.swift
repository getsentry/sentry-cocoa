// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

protocol SentryFeedbackFormPresenterDelegate: AnyObject {
    func feedbackFormPresenterDidDismiss(_ presenter: SentryFeedbackFormPresenter)
}

protocol SentryFeedbackFormPresenter: AnyObject {
    var delegate: SentryFeedbackFormPresenterDelegate? { get set }

    @discardableResult
    func present(screenshot: UIImage?) -> Bool

    func dismiss()
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
