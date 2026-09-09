// swiftlint:disable file_length missing_docs

import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import UIKit

protocol SentryUserFeedbackFormViewModelDelegate: NSObjectProtocol {
    func selectScreenshot()
    func submitFeedback()
    func cancel()
}

@objcMembers
@_spi(Private) public class SentryUserFeedbackFormViewModel: NSObject {
    let config: SentryUserFeedbackConfiguration
    unowned let controller: SentryUserFeedbackFormController
    weak var delegate: SentryUserFeedbackFormViewModelDelegate?
    let screenshot: UIImage?
    // UIImage doesn't preserve the attachment's encoded bytes or metadata.
    private var selectedScreenshotAttachment: Attachment?
    
    static let dateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    init(config: SentryUserFeedbackConfiguration, controller: SentryUserFeedbackFormController, screenshot: UIImage?) {
        self.config = config
        self.controller = controller
        self.screenshot = screenshot
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
        if config.formConfig.useSentryUser {
            field.text = SentrySDKInternal.currentHub().scope.userObject?.name
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
        if config.formConfig.useSentryUser {
            field.text = SentrySDKInternal.currentHub().scope.userObject?.email
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
        // The remove button already represents the attachment to VoiceOver.
        iv.isAccessibilityElement = false
        iv.accessibilityLabel = config.formConfig.screenshotAccessibilityLabel
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        iv.image = self.screenshot
        return iv
    }()

    lazy var screenshotLoadingIndicator = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = config.theme.buttonForeground
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    lazy var addScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.addScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(selectScreenshot), for: .touchUpInside)
        button.accessibilityIdentifier = "io.sentry.feedback.form.add-screenshot"
        button.addSubview(self.screenshotLoadingIndicator)
        NSLayoutConstraint.activate([
            self.screenshotLoadingIndicator.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            self.screenshotLoadingIndicator.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
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
        stack.isHidden = screenshot == nil
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
        
        let messageAndScreenshotStack = UIStackView(arrangedSubviews: [
            self.messageTextView,
            self.addScreenshotButton,
            self.removeScreenshotStack
        ])
        messageAndScreenshotStack.axis = .vertical
        messageAndScreenshotStack.spacing = config.theme.font.lineHeight - config.theme.font.xHeight
        addScreenshotButton.isHidden = screenshot != nil || !config.formConfig.enableScreenshot
        
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
    lazy var addScreenshotButtonHeightConstraint = {
        let constraint = addScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
        // Keep this below UIStackView's hiding constraint so the button can collapse.
        constraint.priority = UILayoutPriority(rawValue: 999)
        return constraint
    }()
    lazy var removeScreenshotButtonHeightConstraint = {
        let constraint = removeScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
        // Keep this below UIStackView's hiding constraint so the screenshot stack can collapse.
        constraint.priority = UILayoutPriority(rawValue: 999)
        return constraint
    }()
    lazy var submitButtonHeightConstraint = submitButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var cancelButtonHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var screenshotImageAspectRatioConstraint = screenshotImageView.widthAnchor.constraint(
        equalTo: screenshotImageView.heightAnchor,
        multiplier: screenshotAspectRatio(for: screenshot)
    )
    
    // the extra 5 pixels was observed experimentally and is invariant under changes in dynamic type sizes
    lazy var messagePlaceholderLeadingConstraint = messageTextViewPlaceholder.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: messageTextView.textContainerInset.left + 5)
    lazy var messagePlaceholderTrailingConstraint = messageTextViewPlaceholder.trailingAnchor.constraint(equalTo: messageTextView.trailingAnchor, constant: messageTextView.textContainerInset.right - 5)
    lazy var messagePlaceholderTopConstraint = messageTextViewPlaceholder.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: messageTextView.textContainerInset.top)
    lazy var messagePlaceholderBottomConstraint = messageTextViewPlaceholder.bottomAnchor.constraint(lessThanOrEqualTo: messageTextView.bottomAnchor, constant: messageTextView.textContainerInset.bottom)
}

// MARK: Constraints

extension SentryUserFeedbackFormViewModel {
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

            screenshotImageView.heightAnchor.constraint(equalTo: removeScreenshotButton.heightAnchor),
            screenshotImageAspectRatioConstraint
        ]
    }
}

// MARK: Actions

extension SentryUserFeedbackFormViewModel {
    func selectScreenshot() {
        delegate?.selectScreenshot()
    }

    func setScreenshot(image: UIImage, attachment: Attachment) {
        selectedScreenshotAttachment = attachment
        screenshotImageView.image = image
        updateScreenshotAspectRatio(for: image)
        addScreenshotButton.isHidden = true
        removeScreenshotStack.isHidden = false
        updateSubmitButtonAccessibilityHint()
    }

    func setScreenshotLoading(_ loading: Bool) {
        addScreenshotButton.isEnabled = !loading
        addScreenshotButton.setTitle(loading ? nil : config.formConfig.addScreenshotButtonLabel, for: .normal)
        submitButton.isEnabled = !loading
        if loading {
            screenshotLoadingIndicator.startAnimating()
        } else {
            screenshotLoadingIndicator.stopAnimating()
        }
    }

    private func screenshotAspectRatio(for image: UIImage?) -> CGFloat {
        guard let image = image, image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    private func updateScreenshotAspectRatio(for image: UIImage) {
        NSLayoutConstraint.deactivate([screenshotImageAspectRatioConstraint])
        screenshotImageAspectRatioConstraint = screenshotImageView.widthAnchor.constraint(
            equalTo: screenshotImageView.heightAnchor,
            multiplier: screenshotAspectRatio(for: image)
        )
        screenshotImageAspectRatioConstraint.isActive = true
    }

    func removeScreenshotTapped() {
        selectedScreenshotAttachment = nil
        screenshotImageView.image = nil
        addScreenshotButton.isHidden = !config.formConfig.enableScreenshot
        removeScreenshotStack.isHidden = true
        updateSubmitButtonAccessibilityHint()
    }
    
    func submitFeedback() {
        delegate?.submitFeedback()
    }
    
    func cancel() {
        delegate?.cancel()
    }
}

// MARK: API

extension SentryUserFeedbackFormViewModel {
    func updateSubmitButtonAccessibilityHint() {
        switch validate() {
        case .success(let hint): submitButton.accessibilityHint = hint
        case .failure(let error): submitButton.accessibilityHint = error.errorDescription
        }
    }
    
    func themeElements() {
        [fullNameTextField, emailTextField].forEach {
            $0.font = config.theme.font
            $0.adjustsFontForContentSizeCategory = true
            $0.textColor = config.theme.inputForeground
            if config.theme.usesDefaultOutlineStyle {
                $0.borderStyle = .roundedRect
            } else {
                $0.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
                $0.layer.borderWidth = config.theme.outlineStyle.outlineWidth
                $0.layer.borderColor = config.theme.outlineStyle.color.cgColor
            }
        }
        
        [fullNameTextField, emailTextField, messageTextView].forEach {
            $0.backgroundColor = config.theme.inputBackground
        }
        
        messageTextView.textColor = config.theme.inputForeground
        
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
            $0.layer.borderColor = config.theme.outlineStyle.color.cgColor
        }
        
        [addScreenshotButton, removeScreenshotButton, cancelButton].forEach {
            $0.backgroundColor = config.theme.buttonBackground
            $0.setTitleColor(config.theme.buttonForeground, for: .normal)
        }
        screenshotLoadingIndicator.color = config.theme.buttonForeground
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
    
    typealias SentryUserFeedbackFormValidation = Result<String, InputError>
    func validate() -> SentryUserFeedbackFormValidation {
        var missing = [String]()
        var hint = ["Will submit feedback"]
        
        if let name = fullNameTextField.textOrNil {
            hint.append("for \(name)")
        } else if config.formConfig.isNameRequired {
            missing.append(config.formConfig.nameLabel.lowercased())
        } else {
            hint.append("with no name")
        }
        
        if let email = emailTextField.textOrNil {
            hint.append("at \(email)")
        } else if config.formConfig.isEmailRequired {
            missing.append(config.formConfig.emailLabel.lowercased())
        } else if fullNameTextField.hasText {
            hint.append("with no email address")
        } else {
            hint.append("or email address")
        }
        
        // include any details available for a screenshot, if included
        if screenshotImageView.image != nil {
            if let accessibilityInfo = screenshotImageView.accessibilityLabel {
                hint.append("including \(accessibilityInfo.lowercased())")
            } else {
                hint.append("including screenshot")
                SentrySDKLog.warning("Required screenshot accessibility info but it was not set.")
            }
        }
        
        // include the message they'll submit
        if let message = messageTextView.textOrNil {
            hint.append("with message: \(message)")
        } else {
            missing.append(config.formConfig.messageLabel.lowercased())
        }
        
        guard missing.isEmpty else {
            let localizedError = InputError.buildDescriptionFor(missingFields: missing, validationErrorMessage: config.formConfig.validationErrorMessage)
            let result = SentryUserFeedbackFormValidation.failure(InputError.validationError(missingFields: missing, localizedError: localizedError))
            return result
        }
        
        return SentryUserFeedbackFormValidation.success(hint.joined(separator: " ").appending("."))
    }
    
    enum InputError: LocalizedError {
        case validationError(missingFields: [String], localizedError: String)
        
        var description: String {
            switch self {
            case .validationError(_, let localizedError):
                return localizedError
            }
        }
        
        var errorDescription: String? {
            return description
        }
        
        static func buildDescriptionFor(missingFields: [String], validationErrorMessage: (Bool) -> String) -> String {
            let list = missingFields.count == 1 ? missingFields[0] : missingFields[0 ..< missingFields.count - 1].joined(separator: ", ") + " and " + missingFields[missingFields.count - 1]
            return "\(validationErrorMessage(missingFields.count > 1 )) \(list)."
        }
    }
    
    func feedbackObject() -> SentryFeedback {
        var attachments: [Attachment]?
        if let selectedScreenshotAttachment = selectedScreenshotAttachment {
            attachments = [selectedScreenshotAttachment]
        } else if let image = screenshotImageView.image, let data = image.pngData() {
            attachments = [Attachment(data: data, filename: "screenshot.png", contentType: "image/png")]
        }
        return SentryFeedback(message: messageTextView.text, name: fullNameTextField.text, email: emailTextField.text, attachments: attachments)
    }
}

extension UITextField {
    var textOrNil: String? {
        guard hasText else { return nil }
        guard let text = text else {
            SentrySDKLog.warning("This branch should be unreachable. UITextField reported .hasText = true but couldn't provide .text in a conditional unwrap.")
            return nil
        }
        return text
    }
}

extension UITextView {
    var textOrNil: String? {
        guard hasText else { return nil }
        guard let text = text else {
            SentrySDKLog.warning("This branch should be unreachable. UITextField reported .hasText = true but couldn't provide .text in a conditional unwrap.")
            return nil
        }
        return text
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK

// swiftlint:enable file_length missing_docs
