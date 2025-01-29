//swiftlint:disable type_body_length

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import PhotosUI
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

// MARK: SentryUserFeedbackFormViewModelDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: SentryUserFeedbackFormViewModelDelegate {
    public func addScreenshotTapped() {
        
#if SENTRY_TEST || SENTRY_TEST_CI
        // the iOS photo picker UI doesn't play nicely with XCUITest, so we need to mock it. we also mock it for unit tests
        set(image: UIImage(), accessibilityInfo: "test image accessibility info")
#else
        guard Bundle.main.canRequestAuthorizationToAttachPhotos else {
            SentryLog.warning("Photos usage was not configured in the info plist with NSPhotoLibraryUsageDescription, but the user was still able to attempt to add a screenshot.")
            return
        }
        
        func presentPicker() {
            DispatchQueue.main.async {
                let imagePickerController = UIImagePickerController()
                imagePickerController.delegate = self
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.allowsEditing = true
                if UIDevice.current.userInterfaceIdiom == .pad {
                    imagePickerController.modalPresentationStyle = .popover
                    // docs state that accessing the `popoverPresentationController` creates one if one doesn't already exist as long as `modalPresentationStyle = .popover`. it's a readonly property so you can't instantiate a new `UIPopoverPresentationController` and assign it.
                    imagePickerController.popoverPresentationController?.sourceView = self.viewModel.addScreenshotButton
                }
                self.present(imagePickerController, animated: self.config.animations)
            }
        }
        
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                    SentryLog.debug("Photos authorization level: \($0)")
                    presentPicker()
                }
            } else {
                PHPhotoLibrary.requestAuthorization {
                    SentryLog.debug("Photos authorization level: \($0)")
                    presentPicker()
                }
            }
        default:
            SentryLog.debug("Photos authorization level: \(status)")
            presentPicker()
        }
#endif // SENTRY_TEST || SENTRY_TEST_CI
    }
    
    func submitFeedback() {
        switch viewModel.validate() {
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
            
            presentAlert(message: error.description, errorCode: 1, info: ["missing_fields": missing, NSLocalizedDescriptionKey: "The user did not complete the feedback form."])
        }
    }
    
    func cancel() {
        delegate?.finished(with: nil)
    }
}

// MARK: UIImagePickerControllerDelegate & UINavigationControllerDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        defer {
            dismiss(animated: config.animations)
        }
        
        guard let photo = info[.editedImage] as? UIImage else {
            SentryLog.warning("Could not get edited image from photo picker.")
            return
        }
        
        let formatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter
        }()
        
        let accessibilityInfo = {
            guard let asset = info[.phAsset] as? PHAsset else {
                SentryLog.warning("Could not get edited image asset information from photo picker.")
                return "Image"
            }
            guard let date = asset.creationDate else {
                SentryLog.warning("Could not get creation date from edited image from photo picker.")
                return "Image"
            }
            return "Image taken \(formatter.string(from: date))"
        }()
        
        set(image: photo, accessibilityInfo: accessibilityInfo)
    }
    
    private func set(image: UIImage, accessibilityInfo: String) {
        viewModel.updateScreenshot(image: image, accessibilityInfo: accessibilityInfo)
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
