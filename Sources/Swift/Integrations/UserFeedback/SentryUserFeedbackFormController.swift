//swiftlint:disable type_body_length

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *)
protocol SentryUserFeedbackFormDelegate: NSObjectProtocol {
    func finished(with feedback: SentryFeedback?)
}

@available(iOS 13.0, *)
@objcMembers
class SentryUserFeedbackFormController: UIViewController {
    let config: SentryUserFeedbackConfiguration
    weak var delegate: (any SentryUserFeedbackFormDelegate)?
    lazy var viewModel = SentryUserFeedbackFormViewModel(config: config, controller: self)
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        config.theme.updateDefaultFonts()
        config.recalculateScaleFactors()
        viewModel.updateLayout()
    }
    
    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackFormDelegate) {
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = config.theme.background
        initLayout()
        viewModel.themeElements()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showedKeyboard(note:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(hidKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Layout
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController {
    func initLayout() {
        viewModel.setScrollViewBottomInset(0)
        view.addSubview(viewModel.scrollView)
        NSLayoutConstraint.activate(viewModel.allConstraints(view: view))
    }
    
    func showedKeyboard(note: Notification) {
        guard let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            SentryLog.warning("Received a keyboard display notification with no frame information.")
            return
        }
        let keyboardViewEndFrame = self.view.convert(keyboardValue.cgRectValue, from: self.view.window)
        viewModel.setScrollViewBottomInset(keyboardViewEndFrame.height - self.view.safeAreaInsets.bottom)
    }
    
    func hidKeyboard() {
        viewModel.setScrollViewBottomInset(0)
    }
}

// MARK: SentryPhotoPickerDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: SentryPhotoPickerDelegate {
    func chose(image: UIImage, accessibilityInfo: String) {
        // these need to happen in this order, because updateSubmitButtonAccessibilityHint uses the value of screenshotImageView.accessibilityLabel
        viewModel.updateScreenshot(image: image, accessibilityInfo: accessibilityInfo)
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

// MARK: SentryUserFeedbackFormViewModelDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: SentryUserFeedbackFormViewModelDelegate {
    public func addScreenshotTapped() {
        config.formConfig.photoPicker?.display(config: config, presenter: self)
    }
    
    func submitFeedback() {
        switch viewModel.lastValidation ?? viewModel.validate() {
        case .success(_):
            let feedback = viewModel.feedbackObject()
            SentryLog.debug("Sending user feedback")
            if let block = config.onSubmitSuccess {
                block(feedback.dataDictionary())
            }
            delegate?.finished(with: feedback)
        case .failure(let error):
            func presentAlert(message: String, errorCode: Int, info: [String: Any]) {
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: config.animations) {
                    if let block = self.config.onSubmitError {
                        // we use NSError here instead of Swift.Error because NSError automatically bridges to Swift.Error, but the same is not true in the other direction if you want to include a userInfo dictionary. Using Swift.Error would require additional implementation for this to work with ObjC consumers.
                        block(NSError(domain: "io.sentry.error", code: errorCode, userInfo: info))
                    }
                }
            }
            
            guard case let SentryUserFeedbackFormViewModel.InputError.validationError(missing) = error else {
                SentryLog.warning("Unexpected error type.")
                presentAlert(message: "Unexpected client error.", errorCode: 2, info: [NSLocalizedDescriptionKey: "Client error: ."])
                return
            }
            
            presentAlert(message: description, errorCode: 1, info: ["missing_fields": missing, NSLocalizedDescriptionKey: "The user did not complete the feedback form."])
        }
    }
    
    func cancel() {
        delegate?.finished(with: nil)
    }
}

// MARK: UITextFieldDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

// MARK: UITextViewDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.messageTextViewPlaceholder.isHidden = textView.text != ""
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable type_body_length
