// swiftlint:disable type_body_length

import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// A view controller that displays the Sentry user feedback form.
@available(iOSApplicationExtension, unavailable)
public final class SentryUserFeedbackFormController: UIViewController {
    let config: SentryUserFeedbackConfiguration
    let screenshot: UIImage?
    var onDidClose: (() -> Void)?
    private var didOpenForm = false
    private var didCloseForm = false
    lazy var viewModel = SentryUserFeedbackFormViewModel(config: config, controller: self, screenshot: screenshot)

    /// Creates a feedback form controller with the specified configuration.
    /// - Parameter config: The configuration for this feedback form instance.
    @objc(initWithConfig:)
    public convenience init(config: SentryUserFeedbackConfiguration) {
        self.init(config: config, image: nil)
    }

    /// Creates a feedback form controller with the specified configuration and image attachment.
    /// - Parameters:
    ///   - config: The configuration for this feedback form instance.
    ///   - image: An optional image to attach to the feedback form.
    @objc(initWithConfig:image:)
    public convenience init(config: SentryUserFeedbackConfiguration, image: UIImage?) {
        config.configureForm?(config.formConfig)
        config.configureTheme?(config.theme)
        config.configureDarkTheme?(config.darkTheme)
        self.init(preparedConfig: config, image: image)
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        config.theme.updateDefaultFonts()
        config.recalculateScaleFactors()
        viewModel.updateLayout()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentationController?.delegate = self
        notifyFormDidOpen()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || navigationController?.isBeingDismissed == true || isMovingFromParent {
            notifyFormDidClose()
        }
    }

    init(preparedConfig config: SentryUserFeedbackConfiguration, image: UIImage?) {
        self.config = config
        self.screenshot = image
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

    /// Creates a feedback form controller from a decoder.
    public required init?(coder: NSCoder) {
        self.config = SentryUserFeedbackConfiguration()
        self.screenshot = nil
        super.init(coder: coder)
        commonInit()
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
            dismissForm()
        case .failure(let error):
            func presentAlert(message: String, errorCode: Int, info: [String: Any]) {
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                // we use NSError here instead of Swift.Error because NSError automatically bridges to Swift.Error, but the same is not true in the other direction if you want to include a userInfo dictionary. Using Swift.Error would require additional implementation for this to work with ObjC consumers.
                config.onSubmitError?(NSError(domain: "io.sentry.error", code: errorCode, userInfo: info))
                present(alert, animated: config.animations)
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
        dismissForm()
    }
}

// MARK: Form lifecycle
extension SentryUserFeedbackFormController {
    private func dismissForm() {
        let completion: () -> Void = { [weak self] in
            self?.notifyFormDidClose()
        }

        dismiss(animated: config.animations, completion: completion)
    }

    private func notifyFormDidOpen() {
        guard !didOpenForm else { return }
        didOpenForm = true
        config.onFormOpen?()
    }

    private func notifyFormDidClose() {
        guard didOpenForm, !didCloseForm else { return }
        didCloseForm = true
        config.onFormClose?()
        onDidClose?()
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
    SentryUserFeedbackFormController(config: .init())
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController(config: .init()))
    .preferredColorScheme(.dark).colorScheme(.dark)
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController(config: .init()))
    .dynamicTypeSize(.accessibility5)
}
#endif // DEBUG && swift(>=5.10)

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK

// swiftlint:enable type_body_length
