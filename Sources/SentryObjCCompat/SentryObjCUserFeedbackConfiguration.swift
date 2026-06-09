// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCUserFeedbackConfiguration) public final class SentryObjCUserFeedbackConfiguration: NSObject {
    internal let wrapped: SentryUserFeedbackConfiguration

    internal init(_ wrapped: SentryUserFeedbackConfiguration) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryUserFeedbackConfiguration()
    }

    @objc public var animations: Bool {
        get { wrapped.animations }
        set { wrapped.animations = newValue }
    }

    @objc public var useShakeGesture: Bool {
        get { wrapped.useShakeGesture }
        set { wrapped.useShakeGesture = newValue }
    }

    @objc public var showFormForScreenshots: Bool {
        get { wrapped.showFormForScreenshots }
        set { wrapped.showFormForScreenshots = newValue }
    }

    @objc public var customButton: UIButton? {
        get { wrapped.customButton }
        set { wrapped.customButton = newValue }
    }

    @objc public var configureForm: ((SentryObjCUserFeedbackFormConfiguration) -> Void)? {
        didSet {
            if let configureForm = configureForm {
                wrapped.configureForm = { configuration in
                    configureForm(SentryObjCUserFeedbackFormConfiguration(configuration))
                }
            } else {
                wrapped.configureForm = nil
            }
        }
    }

    @objc public var tags: [String: Any]? {
        get { wrapped.tags }
        set { wrapped.tags = newValue }
    }

    @objc public var onFormOpen: (() -> Void)? {
        didSet {
            wrapped.onFormOpen = onFormOpen
        }
    }

    @objc public var onFormClose: (() -> Void)? {
        didSet {
            wrapped.onFormClose = onFormClose
        }
    }

    @objc public var onSubmitSuccess: (([String: Any]) -> Void)? {
        didSet {
            wrapped.onSubmitSuccess = onSubmitSuccess
        }
    }

    @objc public var onSubmitError: ((NSError) -> Void)? {
        didSet {
            if let onSubmitError = onSubmitError {
                wrapped.onSubmitError = { error in
                    onSubmitError(error as NSError)
                }
            } else {
                wrapped.onSubmitError = nil
            }
        }
    }

    @objc public var configureTheme: ((SentryObjCUserFeedbackThemeConfiguration) -> Void)? {
        didSet {
            if let configureTheme = configureTheme {
                wrapped.configureTheme = { configuration in
                    configureTheme(SentryObjCUserFeedbackThemeConfiguration(configuration))
                }
            } else {
                wrapped.configureTheme = nil
            }
        }
    }
}
#endif

// swiftlint:enable missing_docs
