//swiftlint:disable todo type_body_length file_length

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
class SentryUserFeedbackForm: UIViewController {
    let config: SentryUserFeedbackConfiguration
    weak var delegate: (any SentryUserFeedbackFormDelegate)?
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        config.theme.updateDefaultFonts()
        config.recalculateScaleFactors()
        updateLayout()
    }
    
    //swiftlint:disable function_body_length
    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackFormDelegate) {
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = config.theme.background
        initLayout()
        themeElements()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showedKeyboard(note:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(hidKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UI Elements
    
    func themeElements() {
        [fullNameTextField, emailTextField].forEach {
            $0.font = config.theme.font
            $0.adjustsFontForContentSizeCategory = true
            if config.theme.outlineStyle == config.theme.defaultOutlineStyle {
                $0.borderStyle = .roundedRect
            } else {
                $0.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
                $0.layer.borderWidth = config.theme.outlineStyle.outlineWidth
                $0.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
            }
        }
        
        [fullNameTextField, emailTextField, messageTextView].forEach {
            $0.backgroundColor = config.theme.inputBackground
        }
        
        [fullNameLabel, emailLabel, messageLabel].forEach {
            $0.font = config.theme.titleFont
            $0.adjustsFontForContentSizeCategory = true
        }
        
        [submitButton, addScreenshotButton, removeScreenshotButton, cancelButton].forEach {
            $0.titleLabel?.font = config.theme.titleFont
            $0.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        
        [submitButton, addScreenshotButton, removeScreenshotButton, cancelButton, messageTextView].forEach {
            $0.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
            $0.layer.borderWidth = config.theme.outlineStyle.outlineWidth
            $0.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        }
        
        [addScreenshotButton, removeScreenshotButton, cancelButton].forEach {
            $0.backgroundColor = config.theme.buttonBackground
            $0.setTitleColor(config.theme.buttonForeground, for: .normal)
        }
    }
    //swiftlint:enable function_body_length
    
    // MARK: Actions
    
    func addScreenshotButtonTapped() {
        // the iOS photo picker UI doesn't play nicely with XCUITest, so we'll just mock the selection here
#if TEST || TESTCI
        //swiftlint:disable force_try force_unwrapping
        let url = Bundle.main.url(forResource: "Tongariro", withExtension: "jpg")!
        let image = try! UIImage(data: Data(contentsOf: url))!
        //swiftlint:ensable force_try force_unwrapping
        addedScreenshot(image: image)
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
#endif // TEST || TESTCI
    }
    
    func removeScreenshotButtonTapped() {
        screenshotImageView.image = nil
        removeScreenshotStack.isHidden = true
        addScreenshotButton.isHidden = false
    }
    
    func validate() -> String? {
        var missing = [String]()
        
        if config.formConfig.isNameRequired && !fullNameTextField.hasText {
            missing.append(config.formConfig.nameLabel.lowercased())
        }
        
        if config.formConfig.isEmailRequired && !emailTextField.hasText {
            missing.append(config.formConfig.emailLabel.lowercased())
        }
        
        if !messageTextView.hasText {
            missing.append(config.formConfig.messageLabel.lowercased())
        }
        
        guard missing.isEmpty else {
            let list = missing.count == 1 ? missing[0] : missing[0 ..< missing.count - 1].joined(separator: ", ") + " and " + missing[missing.count - 1]
            return "You must provide all required information. Please check the following field\(missing.count > 1 ? "s" : ""): \(list)."
        }
        
        return nil
    }
     
    func submitFeedbackButtonTapped() {
        if let message = validate() {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: config.animations)
        } else {
            let feedback = SentryFeedback(message: messageTextView.text, name: fullNameTextField.text, email: emailTextField.text, screenshot: screenshotImageView.image?.pngData())
            SentryLog.log(message: "Sending user feedback", andLevel: .debug)
            delegate?.finished(with: feedback)
        }
    }
    
    func cancelButtonTapped() {
        delegate?.finished(with: nil)
    }
    
    // MARK: Layout
    
    let formElementHeight: CGFloat = 40
    let logoWidth: CGFloat = 47
    lazy var messageTextViewHeightConstraint = messageTextView.heightAnchor.constraint(equalToConstant: config.theme.font.lineHeight * 5)
    lazy var logoViewWidthConstraint = sentryLogoView.widthAnchor.constraint(equalToConstant: logoWidth * config.scaleFactor)
    lazy var fullNameTextFieldHeightConstraint = fullNameTextField.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var emailTextFieldHeightConstraint = emailTextField.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var addScreenshotButtonHeightConstraint = addScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var removeScreenshotButtonHeightConstraint = removeScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var submitButtonHeightConstraint = submitButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var cancelButtonHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var screenshotImageAspectRatioConstraint = screenshotImageView.widthAnchor.constraint(equalTo: screenshotImageView.heightAnchor)
    
    // the extra 5 pixels was observed experimentally and is invariant under changes in dynamic type sizes
    lazy var messagePlaceholderLeadingConstraint = messageTextViewPlaceholder.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: messageTextView.textContainerInset.left + 5)
    lazy var messagePlaceholderTrailingConstraint = messageTextViewPlaceholder.trailingAnchor.constraint(equalTo: messageTextView.trailingAnchor, constant: messageTextView.textContainerInset.right - 5)
    lazy var messagePlaceholderTopConstraint = messageTextViewPlaceholder.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: messageTextView.textContainerInset.top)
    lazy var messagePlaceholderBottomConstraint = messageTextViewPlaceholder.bottomAnchor.constraint(equalTo: messageTextView.bottomAnchor, constant: messageTextView.textContainerInset.bottom)
    
    func setScrollViewBottomInset(_ inset: CGFloat) {
        scrollView.contentInset = .init(top: config.margin, left: config.margin, bottom: inset + config.margin, right: config.margin)
        scrollView.scrollIndicatorInsets = .init(top: 0, left: 0, bottom: inset, right: 0)
    }
    
    func initLayout() {
        setScrollViewBottomInset(0)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2 * config.margin),
            
            messageTextViewHeightConstraint,
            
            logoViewWidthConstraint,
            sentryLogoView.heightAnchor.constraint(equalTo: sentryLogoView.widthAnchor, multiplier: 41 / 47),

            fullNameTextFieldHeightConstraint,
            emailTextFieldHeightConstraint,
            addScreenshotButtonHeightConstraint,
            removeScreenshotButtonHeightConstraint,
            submitButtonHeightConstraint,
            cancelButtonHeightConstraint,
            
            messagePlaceholderLeadingConstraint,
            messagePlaceholderTopConstraint,
            messagePlaceholderTrailingConstraint,
            
            screenshotImageView.heightAnchor.constraint(equalTo: addScreenshotButton.heightAnchor),
            screenshotImageAspectRatioConstraint
        ])
    }
    
    func updateLayout() {
        let verticalPadding: CGFloat = 8
        messageTextView.textContainerInset = .init(top: verticalPadding * config.scaleFactor, left: 2 * config.scaleFactor, bottom: verticalPadding * config.scaleFactor, right: 2 * config.scaleFactor)
        
        messageTextViewHeightConstraint.constant = config.theme.font.lineHeight * 5
        logoViewWidthConstraint.constant = logoWidth * config.scaleFactor
        messagePlaceholderLeadingConstraint.constant = messageTextView.textContainerInset.left + 5
        messagePlaceholderTrailingConstraint.constant = messageTextView.textContainerInset.right - 5
        messagePlaceholderTopConstraint.constant = messageTextView.textContainerInset.top
        fullNameTextFieldHeightConstraint.constant = formElementHeight * config.scaleFactor
        emailTextFieldHeightConstraint.constant = formElementHeight * config.scaleFactor
        addScreenshotButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        removeScreenshotButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        submitButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        cancelButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
    }
    
    func showedKeyboard(note: Notification) {
        guard let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardViewEndFrame = self.view.convert(keyboardValue.cgRectValue, from: self.view.window)
        self.setScrollViewBottomInset(keyboardViewEndFrame.height - self.view.safeAreaInsets.bottom)
    }
    
    func hidKeyboard() {
        self.setScrollViewBottomInset(0)
    }
    
    // MARK: UI Elements
    
    lazy var formTitleLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.formTitle
        label.font = config.theme.headerFont
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    lazy var sentryLogoView = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = SentryIconography.logo
        shapeLayer.fillColor = self.config.theme.foreground.cgColor
        
        let view = UIView(frame: .zero)
        view.layer.addSublayer(shapeLayer)
        view.isAccessibilityElement = true
        view.accessibilityLabel = "provided by Sentry" // ???: what do we want to say here?
        return view
    }()
    
    lazy var fullNameLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.nameLabelContents
        return label
    }()
    
    lazy var fullNameTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.namePlaceholder
        field.accessibilityLabel = config.formConfig.nameTextFieldAccessibilityLabel
        field.accessibilityIdentifier = "io.sentry.feedback.form.name"
        field.delegate = self
        field.autocapitalizationType = .words
        field.returnKeyType = .done
        if config.useSentryUser {
            field.text = sentry_getCurrentUser()?.name
        }
        return field
    }()
    
    lazy var emailLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.emailLabelContents
        return label
    }()
    
    lazy var emailTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.emailPlaceholder
        field.accessibilityLabel = config.formConfig.emailTextFieldAccessibilityLabel
        field.accessibilityIdentifier = "io.sentry.feedback.form.email"
        field.delegate = self
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        if config.useSentryUser {
            field.text = sentry_getCurrentUser()?.email
        }
        return field
    }()
    
    lazy var messageLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.messageLabelContents
        return label
    }()
    
    lazy var messageTextViewPlaceholder = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.messagePlaceholder
        label.font = config.theme.font
        label.numberOfLines = 0
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()
    
    lazy var messageTextView = {
        let textView = UITextView(frame: .zero)
        textView.font = config.theme.font
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityLabel = config.formConfig.messageTextViewAccessibilityLabel
        textView.delegate = self
        textView.accessibilityIdentifier = "io.sentry.feedback.form.message"
        return textView
    }()
    
    lazy var screenshotImageView = {
        let iv = UIImageView()
        iv.isAccessibilityElement = true
        return iv
    }()
    
    lazy var addScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.addScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(addScreenshotButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.add-screenshot"
        button.accessibilityHint = "Will present the iOS photo picker for you to choose an image to attach to the feedback report."
        return button
    }()
    
    lazy var removeScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.removeScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.removeScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(removeScreenshotButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.remove-screenshot"
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.submitButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.submitButtonAccessibilityLabel
        button.backgroundColor = config.theme.submitBackground
        button.setTitleColor(config.theme.submitForeground, for: .normal)
        button.addTarget(self, action: #selector(submitFeedbackButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.submit"
        button.accessibilityHint = submitAccessibilityHint
        return button
    }()
    
    lazy var submitAccessibilityHint = {
        if let message = validate() {
            return message
        }
        
        var hint = "Will submit feedback "
        
        if let name = fullNameTextField.text {
            hint += "for \(name) "
        } else {
            hint += "with no name "
        }
        
        if let email = emailTextField.text {
            hint += "at \(email) "
        } else {
            if fullNameTextField.text != nil {
                hint += "with no email "
            } else {
                hint += "or email "
            }
        }
        
        if let screenshot = screenshotImageView.image {
            if let imageDescription = screenshotImageView.accessibilityLabel {
                hint += "and \(imageDescription)"
            } else {
                SentryLog.warning("Expected screenshot image view to have accessibility label containing image metadata")
                hint += "and attached image"
            }
        }
        
        if let message = messageTextView.text {
            hint += "with message: \(message)"
        }
         
        return hint
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.cancelButtonAccessibilityLabel
        button.accessibilityIdentifier = "io.sentry.feedback.form.cancel"
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var removeScreenshotStack = {
        let stack = UIStackView(arrangedSubviews: [self.screenshotImageView, self.removeScreenshotButton])
        stack.spacing = config.theme.font.lineHeight - config.theme.font.xHeight
        return stack
    }()
    
    lazy var stack = {
        let headerStack = UIStackView(arrangedSubviews: [self.formTitleLabel])
        if self.config.formConfig.showBranding {
            headerStack.addArrangedSubview(self.sentryLogoView)
        }
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 50
        
        stack.addArrangedSubview(headerStack)
        
        let inputStack = UIStackView()
        inputStack.axis = .vertical
        inputStack.spacing = config.theme.font.xHeight
        
        if self.config.formConfig.showName {
            inputStack.addArrangedSubview(self.fullNameLabel)
            inputStack.addArrangedSubview(self.fullNameTextField)
        }
        
        if self.config.formConfig.showEmail {
            inputStack.addArrangedSubview(self.emailLabel)
            inputStack.addArrangedSubview(self.emailTextField)
        }
        
        inputStack.addArrangedSubview(self.messageLabel)
        
        let messageAndScreenshotStack = UIStackView(arrangedSubviews: [self.messageTextView])
        messageAndScreenshotStack.axis = .vertical
        
        if self.config.formConfig.enableScreenshot {
            messageAndScreenshotStack.addArrangedSubview(self.addScreenshotButton)
            messageAndScreenshotStack.addArrangedSubview(removeScreenshotStack)
            self.removeScreenshotStack.isHidden = true
        }
        messageAndScreenshotStack.spacing = config.theme.font.lineHeight - config.theme.font.xHeight
        
        inputStack.addArrangedSubview(messageAndScreenshotStack)
        
        stack.addArrangedSubview(inputStack)
        
        let controlsStack = UIStackView()
        controlsStack.axis = .vertical
        controlsStack.spacing = config.theme.font.lineHeight - config.theme.font.xHeight
        controlsStack.addArrangedSubview(self.submitButton)
        controlsStack.addArrangedSubview(self.cancelButton)
        stack.addArrangedSubview(controlsStack)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }()
    
    lazy var scrollView = {
        let scrollView = UIScrollView(frame: view.bounds)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(messageTextViewPlaceholder)
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
}

// MARK: UITextFieldDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackForm: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: UITextViewDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackForm: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        messageTextViewPlaceholder.isHidden = textView.text != ""
    }
}

// MARK: UIImagePickerControllerDelegate & UINavigationControllerDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackForm: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
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
        
        guard let photo = info[.editedImage] as? UIImage else {
            // TODO: handle error
            return
        }
        addedScreenshot(image: photo)
         
        guard let asset = info[.phAsset] as? PHAsset else {
            // TODO: handle error
            return
        }
        
        guard let date = asset.creationDate else {
            // TODO: handle error
            return
        }
        screenshotImageView.accessibilityLabel = "Image taken \(SentryUserFeedbackForm.formatter.string(from: date))"
    }
    
    func addedScreenshot(image: UIImage) {
        screenshotImageView.image = image
        screenshotImageAspectRatioConstraint.isActive = false
        screenshotImageAspectRatioConstraint = screenshotImageView.widthAnchor.constraint(equalTo: screenshotImageView.heightAnchor, multiplier: image.size.width / image.size.height)
        screenshotImageAspectRatioConstraint.isActive = true
        addScreenshotButton.isHidden = true
        removeScreenshotStack.isHidden = false
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable todo type_body_length file_length
