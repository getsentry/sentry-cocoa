import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *)
protocol SentryUserFeedbackFormDelegate: NSObjectProtocol {
    func cancelled()
    func confirmed()
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
    
    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackFormDelegate) {
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = config.theme.background
        initLayout()
        themeElements()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    func addScreenshotButtonTapped() {
        
    }
    
    func removeScreenshotButtonTapped() {
        
    }
    
    //swiftlint:disable todo
    func submitFeedbackButtonTapped() {
        // TODO: validate and package entries
        delegate?.confirmed()
    }
    //swiftlint:enable todo
    
    func cancelButtonTapped() {
        delegate?.cancelled()
    }
    
    // MARK: Layout
    
    let formElementHeight: CGFloat = 40
    let logoWidth: CGFloat = 47
    lazy var messageTextViewHeightConstraint = messageTextView.heightAnchor.constraint(equalToConstant: config.theme.font.lineHeight * 5)
    lazy var logoViewWidthConstraint = sentryLogoView.widthAnchor.constraint(equalToConstant: logoWidth * config.scaleFactor)
    lazy var messagePlaceholderLeadingConstraint = messageTextViewPlaceholder.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: messageTextView.textContainerInset.left + 5)
    lazy var messagePlaceholderTopConstraint = messageTextViewPlaceholder.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: messageTextView.textContainerInset.top)
    lazy var fullNameTextFieldHeightConstraint = fullNameTextField.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var emailTextFieldHeightConstraint = emailTextField.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var addScreenshotButtonHeightConstraint = addScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var removeScreenshotButtonHeightConstraint = removeScreenshotButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var submitButtonHeightConstraint = submitButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    lazy var cancelButtonHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: formElementHeight * config.scaleFactor)
    
    func initLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.margin),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: config.margin),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -config.margin),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.margin),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            messageTextViewHeightConstraint,
            
            logoViewWidthConstraint,
            sentryLogoView.heightAnchor.constraint(equalTo: sentryLogoView.widthAnchor, multiplier: 41 / 47),

            fullNameTextFieldHeightConstraint,
            emailTextFieldHeightConstraint,
            addScreenshotButtonHeightConstraint,
            removeScreenshotButtonHeightConstraint,
            submitButtonHeightConstraint,
            cancelButtonHeightConstraint,
            
            // the extra 5 pixels was observed experimentally and is invariant under changes in dynamic type sizes
            messagePlaceholderLeadingConstraint,
            messagePlaceholderTopConstraint
        ])
    }
    
    /// Update the constants of constraints and any other layout, like transforms, in response to e.g. accessibility dynamic text size changes.
    func updateLayout() {
        let verticalPadding: CGFloat = 8
        messageTextView.textContainerInset = .init(top: verticalPadding * config.scaleFactor, left: 2 * config.scaleFactor, bottom: verticalPadding * config.scaleFactor, right: 2 * config.scaleFactor)
        
        messageTextViewHeightConstraint.constant = config.theme.font.lineHeight * 5
        logoViewWidthConstraint.constant = logoWidth * config.scaleFactor
        messagePlaceholderLeadingConstraint.constant = messageTextView.textContainerInset.left + 5
        messagePlaceholderTopConstraint.constant = messageTextView.textContainerInset.top
        fullNameTextFieldHeightConstraint.constant = formElementHeight * config.scaleFactor
        emailTextFieldHeightConstraint.constant = formElementHeight * config.scaleFactor
        addScreenshotButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        removeScreenshotButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        submitButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
        cancelButtonHeightConstraint.constant = formElementHeight * config.scaleFactor
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
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    lazy var messageTextView = {
        let textView = UITextView(frame: .zero)
        textView.font = config.theme.font
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityLabel = config.formConfig.messageTextViewAccessibilityLabel
        textView.delegate = self
        return textView
    }()
    
    lazy var addScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.addScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(addScreenshotButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var removeScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.removeScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.removeScreenshotButtonAccessibilityLabel
        button.addTarget(self, action: #selector(removeScreenshotButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.submitButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.submitButtonAccessibilityLabel
        button.backgroundColor = config.theme.submitBackground
        button.setTitleColor(config.theme.submitForeground, for: .normal)
        button.addTarget(self, action: #selector(submitFeedbackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.cancelButtonAccessibilityLabel
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
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
        return scrollView
    }()
}

// MARK: UITextViewDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackForm: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        messageTextViewPlaceholder.isHidden = textView.text != ""
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
