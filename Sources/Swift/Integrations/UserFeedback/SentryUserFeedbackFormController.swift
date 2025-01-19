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

// MARK: Private

@available(iOS 13.0, *)
extension SentryUserFeedbackFormController {
    func addedScreenshot(info: [UIImagePickerController.InfoKey: Any]) {
        guard let photo = info[.editedImage] as? UIImage else {
            SentryLog.warning("Could not get edited image from photo picker.")
            return
        }
        
        viewModel.screenshotImageView.image = photo
        viewModel.updateScreenshotImageViewAspectRatioConstraint(image: photo)
        viewModel.addScreenshotButton.isHidden = true
        viewModel.removeScreenshotStack.isHidden = false
        viewModel.updateSubmitButtonAccessibilityHint()
        
        guard let asset = info[.phAsset] as? PHAsset else {
            SentryLog.warning("Could not get edited image asset information from photo picker.")
            viewModel.setScreenshotImageAccessibilityLabel("Image")
            return
        }
        guard let date = asset.creationDate else {
            SentryLog.warning("Could not get creation date from edited image from photo picker.")
            viewModel.setScreenshotImageAccessibilityLabel("Image")
            return
        }
        viewModel.setScreenshotImageAccessibilityLabel("Image taken \(SentryUserFeedbackFormController.formatter.string(from: date))")
    }
 
    // MARK: Layout
    
    func initLayout() {
        viewModel.setScrollViewBottomInset(0)
        view.addSubview(viewModel.scrollView)
        NSLayoutConstraint.activate(viewModel.allConstraints(view: view))
    }
    
    func showedKeyboard(note: Notification) {
        guard let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
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
    
#if SENTRY_TEST || SENTRY_TEST_CI
    class TestPHAsset: PHAsset, @unchecked Sendable {
        let testCreationDate: Date
        
        init(testCreationDate: Date) {
            self.testCreationDate = testCreationDate
            super.init()
        }
        
        override var creationDate: Date? {
            testCreationDate
        }
    }
#endif // SENTRY_TEST || SENTRY_TEST_CI
    
    public func addScreenshotTapped() {
        // the iOS photo picker UI doesn't play nicely with XCUITest, so we'll just mock the selection here
#if SENTRY_TEST || SENTRY_TEST_CI
        //swiftlint:disable force_try force_unwrapping
        let url = Bundle.main.url(forResource: "Tongariro", withExtension: "jpg")!
        let image = try! UIImage(data: Data(contentsOf: url))!
        //swiftlint:ensable force_try force_unwrapping
        let phasset = TestPHAsset(testCreationDate: Date())
        addedScreenshot(info: [
            .editedImage: image,
            .phAsset: phasset
        ])
        return
#else
        
        func presentPicker() {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.allowsEditing = true
            DispatchQueue.main.async {
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
    
    func removeScreenshotTapped() {
        viewModel.screenshotImageView.image = nil
        viewModel.removeScreenshotStack.isHidden = true
        viewModel.addScreenshotButton.isHidden = false
    }
    
    func submitFeedback() {
        if let missing = viewModel.validate() {
            let alert = UIAlertController(title: "Error", message: viewModel.message(for: missing), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: config.animations) {
                if let block = self.config.onSubmitError {
                    // we use NSError here instead of Swift.Error because NSError automatically bridges to Swift.Error, but the same is not true in the other direction if you want to include a userInfo dictionary. Using Swift.Error would require additional implementation for this to work with ObjC consumers.
                    block(NSError(domain: "io.sentry.error", code: 1, userInfo: ["missing_fields": missing, NSLocalizedDescriptionKey: "The user did not complete the feedback form."]))
                }
            }
            return
        }
        
        let feedback = viewModel.feedbackObject()
        SentryLog.debug("Sending user feedback")
        if let block = config.onSubmitSuccess {
            block(feedback.dataDictionary())
        }
        delegate?.finished(with: feedback)
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
}

// MARK: UITextViewDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.messageTextViewPlaceholder.isHidden = textView.text != ""
    }
}

// MARK: UIImagePickerControllerDelegate & UINavigationControllerDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    static let formatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        defer {
            dismiss(animated: config.animations)
        }
        
        addedScreenshot(info: info)
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable type_body_length
