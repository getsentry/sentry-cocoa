//swiftlint:disable file_length

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import PhotosUI
import UIKit

protocol SentryUserFeedbackFormViewModelDelegate: NSObjectProtocol {
    func addScreenshotTapped()
    func removeScreenshotTapped()
    func submitFeedback()
    func cancel()
}

@available(iOS 13.0, *)
@objcMembers
class SentryUserFeedbackFormViewModel: NSObject {
    let config: SentryUserFeedbackConfiguration
    unowned let controller: SentryUserFeedbackFormController
    weak var delegate: SentryUserFeedbackFormViewModelDelegate?
    
    init(config: SentryUserFeedbackConfiguration, controller: SentryUserFeedbackFormController) {
        self.config = config
        self.controller = controller
        super.init()
        delegate = controller
    }
    
    // MARK: UI
    
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
        view.accessibilityLabel = "provided by Sentry"
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
        field.delegate = controller
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
        field.delegate = controller
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
        textView.delegate = controller
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
        button.addTarget(self, action: #selector(addScreenshotTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.add-screenshot"
        button.accessibilityHint = "Will present the iOS photo picker for you to choose an image to attach to the feedback report."
        return button
    }()
    
    lazy var removeScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.removeScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.removeScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(removeScreenshotTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.remove-screenshot"
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.submitButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.submitButtonAccessibilityLabel
        button.backgroundColor = config.theme.submitBackground
        button.setTitleColor(config.theme.submitForeground, for: .normal)
        button.addTarget(self, action: #selector(submitFeedback), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.submit"
        return button
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.cancelButtonAccessibilityLabel
        button.accessibilityIdentifier = "io.sentry.feedback.form.cancel"
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
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
        let scrollView = UIScrollView(frame: controller.view.bounds)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(messageTextViewPlaceholder)
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
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
    
    func allConstraints(view: UIView) -> [NSLayoutConstraint] {
        [
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
            messagePlaceholderBottomConstraint,
            
            screenshotImageView.heightAnchor.constraint(equalTo: addScreenshotButton.heightAnchor),
            screenshotImageAspectRatioConstraint
        ]
    }
}

// MARK: Actions

@available(iOS 13.0, *)
extension SentryUserFeedbackFormViewModel {
    func addScreenshotTapped() {
        delegate?.addScreenshotTapped()
    }
    
    func removeScreenshotTapped() {
        delegate?.removeScreenshotTapped()
    }
    
    func submitFeedback() {
        delegate?.submitFeedback()
    }
    
    func cancel() {
        delegate?.cancel()
    }
}

// MARK: API

@available(iOS 13.0, *)
extension SentryUserFeedbackFormViewModel {
    func updateSubmitButtonAccessibilityHint() {
        submitButton.accessibilityHint = submitAccessibilityHint()
    }
    
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
    
    func setScrollViewBottomInset(_ inset: CGFloat) {
        scrollView.contentInset = .init(top: config.margin, left: config.margin, bottom: inset + config.margin, right: config.margin)
        scrollView.scrollIndicatorInsets = .init(top: 0, left: 0, bottom: inset, right: 0)
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
    
    func setScreenshotImageAccessibilityLabel(_ value: String) {
        screenshotImageView.accessibilityLabel = value
    }
    
    func updateScreenshotImageViewAspectRatioConstraint(image: UIImage) {
        // you cannot dynamically change the multiplier on a constraint. you must deactivate the old instance, create a new instance, and then activate that one
        screenshotImageAspectRatioConstraint.isActive = false
        screenshotImageAspectRatioConstraint = screenshotImageView.widthAnchor.constraint(equalTo: screenshotImageView.heightAnchor, multiplier: image.size.width / image.size.height)
        screenshotImageAspectRatioConstraint.isActive = true
    }
    
    func validate() -> [String]? {
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
        
        guard !missing.isEmpty else {
            return nil
        }
        
        return missing
    }
    
    func message(for missingFields: [String]) -> String {
        let list = missingFields.count == 1 ? missingFields[0] : missingFields[0 ..< missingFields.count - 1].joined(separator: ", ") + " and " + missingFields[missingFields.count - 1]
        return "You must provide all required information. Please check the following field\(missingFields.count > 1 ? "s" : ""): \(list)."
    }
    
    func feedbackObject() -> SentryFeedback {
        SentryFeedback(message: messageTextView.text, name: fullNameTextField.text, email: emailTextField.text, screenshot: screenshotImageView.image?.pngData())
    }
}

// MARK: Accessibility

@available(iOS 13.0, *)
extension SentryUserFeedbackFormViewModel {
    func submitAccessibilityHint() -> String {
        if let missing = validate() {
            return message(for: missing)
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
        
        if screenshotImageView.image != nil {
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
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable file_length
