// swiftlint:disable type_body_length

import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension, unavailable)
protocol SentryUserFeedbackFormDelegate: NSObjectProtocol {
    func userFeedbackFormWillOpen(_ form: SentryUserFeedbackFormController)
    func userFeedbackFormDidClose(_ form: SentryUserFeedbackFormController)
}

extension SentryUserFeedbackFormDelegate {
    func userFeedbackFormWillOpen(_ form: SentryUserFeedbackFormController) { }
}

/// A view controller that displays the Sentry user feedback form.
///
/// If the managed User Feedback integration is installed, the SDK temporarily hides the feedback widget while this
/// controller is visible.
///
/// - warning: This is an experimental feature and may still have bugs.
@available(iOSApplicationExtension, unavailable)
public final class SentryUserFeedbackFormController: UIViewController {
    let config: SentryUserFeedbackConfiguration
    let screenshot: UIImage?
    weak var delegate: SentryUserFeedbackFormDelegate?
    var didMoveToParent: ((SentryUserFeedbackFormController) -> Void)?
    private enum FormLifecycleState {
        case idle
        case willOpen
        case didOpen
        case didClose
    }
    private var formLifecycleState: FormLifecycleState = .idle
    lazy var viewModel = SentryUserFeedbackFormViewModel(config: config, controller: self, screenshot: screenshot)

    /// Creates a feedback form controller using the global configuration from `SentryOptions.configureUserFeedback`.
    /// - warning: This is an experimental feature and may still have bugs.
    @nonobjc public convenience init() {
        self.init(screenshot: nil, configure: nil)
    }

    /// Creates a feedback form controller using the global configuration and an optional form-specific configuration.
    ///
    /// Per-presentation configuration only affects the displayed form. Widget, custom button,
    /// screenshot trigger, and shake gesture settings are global and ignored for individual presentations.
    /// - Parameters:
    ///   - screenshot: An optional screenshot to attach to the feedback form.
    ///   - configure: A closure to customize this feedback form presentation.
    /// - warning: This is an experimental feature and may still have bugs.
    @nonobjc public convenience init(
        screenshot: UIImage? = nil,
        configure: SentryUserFeedbackConfigurationCallback? = nil
    ) {
        let config = Self.globalConfigurationOrDefault().configurationForPresentation(configure: configure)
        self.init(preparedConfig: config, screenshot: screenshot)
        delegate = Self.installedFeedbackIntegration()?.driver
    }

    static func globalConfigurationOrDefault(
        defaultConfiguration: @autoclosure () -> SentryUserFeedbackConfiguration = SentryUserFeedbackConfiguration()
    ) -> SentryUserFeedbackConfiguration {
        guard let integration = installedFeedbackIntegration() else {
            SentrySDKLog.debug("Using default feedback configuration because user feedback is not configured in SentryOptions")
            let config = defaultConfiguration()
            config.applyConfigurationBuilders()
            return config
        }
        return integration.driver.configuration
    }

    private static func installedFeedbackIntegration() -> UserFeedbackIntegration<SentryDependencyContainer>? {
        return SentrySDKInternal.currentHub().getInstalledIntegration(UserFeedbackIntegration<SentryDependencyContainer>.self)
            as? UserFeedbackIntegration<SentryDependencyContainer>
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        config.theme.updateDefaultFonts()
        config.recalculateScaleFactors()
        viewModel.updateLayout()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetFormLifecycleIfNeeded()
        notifyFormWillOpen()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resetFormLifecycleIfNeeded()
        presentationController?.delegate = self
        notifyFormDidOpen()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard presentedViewController == nil else { return }
        guard isBeingDismissedOrRemovedFromHierarchy else { return }
        notifyFormDidClose()
    }

    override public func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        didMoveToParent?(self)
    }

    private var isBeingDismissedOrRemovedFromHierarchy: Bool {
        if isBeingDismissed || isMovingFromParent {
            return true
        }

        var ancestor = parent
        while let viewController = ancestor {
            if viewController.isBeingDismissed || viewController.isMovingFromParent {
                return true
            }
            ancestor = viewController.parent
        }

        return false
    }

    init(preparedConfig config: SentryUserFeedbackConfiguration, screenshot: UIImage?) {
        self.config = config
        self.screenshot = screenshot
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        view.backgroundColor = config.theme.background
        initLayout()
        viewModel.themeElements()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showedKeyboard(note:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(hidKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    /// Unavailable. Use `init()` or `init(screenshot:configure:)` instead.
    @available(*, unavailable, message: "Use init() or init(screenshot:configure:) instead.")
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Use init() or init(screenshot:configure:) instead.")
    }

    /// Unavailable. Use `init()` or `init(screenshot:configure:)` instead.
    @available(*, unavailable, message: "Use init() or init(screenshot:configure:) instead.")
    public required init?(coder: NSCoder) {
        fatalError("Use init() or init(screenshot:configure:) instead.")
    }
}

// MARK: Layout
extension SentryUserFeedbackFormController {
    func initLayout() {
        viewModel.setScrollViewBottomInset(0)
        view.addSubview(viewModel.scrollView)
        NSLayoutConstraint.activate(viewModel.allConstraints(view: view))
    }

    @objc
    func showedKeyboard(note: Notification) {
        guard let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            SentrySDKLog.warning("Received a keyboard display notification with no frame information.")
            return
        }
        let keyboardViewEndFrame = self.view.convert(keyboardValue.cgRectValue, from: self.view.window)
        viewModel.setScrollViewBottomInset(keyboardViewEndFrame.height - self.view.safeAreaInsets.bottom)
    }

    @objc
    func hidKeyboard() {
        viewModel.setScrollViewBottomInset(0)
    }
}

// MARK: SentryUserFeedbackFormViewModelDelegate
extension SentryUserFeedbackFormController: SentryUserFeedbackFormViewModelDelegate {
    func submitFeedback() {
        switch viewModel.validate() {
        case .success:
            let feedback = viewModel.feedbackObject()
            SentrySDKLog.debug("Sending user feedback")
            if let block = config.onSubmitSuccess {
                block(feedback.dataDictionary())
            }
            SentrySDK.capture(feedback: feedback)
            dismiss(animated: config.animations)
        case .failure(let error):
            func presentAlert(message: String, errorCode: Int, info: [String: Any]) {
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: config.animations) { [config] in
                    // we use NSError here instead of Swift.Error because NSError automatically bridges to Swift.Error, but the same is not true in the other direction if you want to include a userInfo dictionary. Using Swift.Error would require additional implementation for this to work with ObjC consumers.
                    config.onSubmitError?(NSError(domain: "io.sentry.error", code: errorCode, userInfo: info))
                }
            }

            guard case let SentryUserFeedbackFormViewModel.InputError.validationError(missing, _) = error,
                let errorDescription = error.errorDescription else {
                SentrySDKLog.warning("Unexpected error type.")
                presentAlert(message: config.formConfig.unexpectedErrorText, errorCode: 2, info: [NSLocalizedDescriptionKey: "Client error: ."])
                return
            }

            presentAlert(message: errorDescription, errorCode: 1, info: ["missing_fields": missing, NSLocalizedDescriptionKey: "The user did not complete the feedback form."])
        }
    }

    func cancel() {
        dismiss(animated: config.animations)
    }
}

// MARK: Form lifecycle
extension SentryUserFeedbackFormController {
    private func resetFormLifecycleIfNeeded() {
        guard case .didClose = formLifecycleState else { return }
        formLifecycleState = .idle
    }

    private func notifyFormWillOpen() {
        guard case .idle = formLifecycleState else { return }
        formLifecycleState = .willOpen
        delegate?.userFeedbackFormWillOpen(self)
    }

    private func notifyFormDidOpen() {
        if case .idle = formLifecycleState {
            notifyFormWillOpen()
        }

        guard case .willOpen = formLifecycleState else { return }
        formLifecycleState = .didOpen
        config.onFormOpen?()
    }

    private func notifyFormDidClose() {
        switch formLifecycleState {
        case .willOpen:
            formLifecycleState = .didClose
            delegate?.userFeedbackFormDidClose(self)
        case .didOpen:
            formLifecycleState = .didClose
            config.onFormClose?()
            delegate?.userFeedbackFormDidClose(self)
        case .idle, .didClose:
            return
        }
    }
}

// MARK: UIAdaptivePresentationControllerDelegate
extension SentryUserFeedbackFormController: UIAdaptivePresentationControllerDelegate {
    /// Notifies feedback lifecycle callbacks when the user dismisses the form interactively.
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        notifyFormDidClose()
    }
}

// MARK: UITextFieldDelegate
extension SentryUserFeedbackFormController: UITextFieldDelegate {
    /// Handles the return key for feedback form text fields.
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    /// Updates validation state when feedback form text fields change.
    public func textFieldDidChangeSelection(_ textField: UITextField) {
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

// MARK: UITextViewDelegate
extension SentryUserFeedbackFormController: UITextViewDelegate {
    /// Updates validation state when the feedback message changes.
    public func textViewDidChange(_ textView: UITextView) {
        viewModel.messageTextViewPlaceholder.isHidden = textView.text != ""
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

#if DEBUG && swift(>=5.10)
import SwiftUI

struct ViewControllerWrapper: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

@available(iOS 17.0, *)
#Preview {
    SentryUserFeedbackFormController()
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController())
    .preferredColorScheme(.dark).colorScheme(.dark)
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController())
    .dynamicTypeSize(.accessibility5)
}
#endif // DEBUG && swift(>=5.10)

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK

// swiftlint:enable type_body_length
