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
    
    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackFormDelegate) {
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        
        view.backgroundColor = .systemBackground
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: config.spacing),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -config.spacing),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.spacing),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            messageTextView.heightAnchor.constraint(equalToConstant: config.theme.font.lineHeight * 5),
            
            sentryLogoView.widthAnchor.constraint(equalToConstant: 72),
            sentryLogoView.heightAnchor.constraint(equalToConstant: 66)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    func addScreenshotButtonTapped() {
        
    }
    
    func removeScreenshotButtonTapped() {
        
    }
    
    func submitFeedbackButtonTapped() {
        // TODO: validate and package entries
        delegate?.confirmed()
    }
    
    func cancelButtonTapped() {
        delegate?.cancelled()
    }
    
    // MARK: UI
    
    lazy var formTitleLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.formTitle
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
        label.text = fullLabelText(labelText: config.formConfig.nameLabel, required: config.formConfig.isNameRequired)
        return label
    }()
    
    lazy var fullNameTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.namePlaceholder
        if config.theme.outlineStyle == config.theme.defaultOutlineStyle {
            field.borderStyle = .roundedRect
        } else {
            field.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
            field.layer.borderWidth = config.theme.outlineStyle.outlineWidth
            field.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        }
        field.accessibilityLabel = config.formConfig.nameTextFieldAccessibilityLabel
        return field
    }()
    
    lazy var emailLabel = {
        let label = UILabel(frame: .zero)
        label.text = fullLabelText(labelText: config.formConfig.emailLabel, required: config.formConfig.isEmailRequired)
        return label
    }()
    
    lazy var emailTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.emailPlaceholder
        if config.theme.outlineStyle == config.theme.defaultOutlineStyle {
            field.borderStyle = .roundedRect
        } else {
            field.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
            field.layer.borderWidth = config.theme.outlineStyle.outlineWidth
            field.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        }
        field.accessibilityLabel = config.formConfig.emailTextFieldAccessibilityLabel
        return field
    }()
    
    lazy var messageLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.messageLabel
        return label
    }()
    
    lazy var messageTextView = {
        let textView = UITextView(frame: .zero)
        textView.text = config.formConfig.messagePlaceholder // TODO: color the text as placeholder if this is the content of the textview, otherwise change to regular foreground color
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        textView.layer.borderWidth = config.theme.outlineStyle.outlineWidth
        textView.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        textView.accessibilityLabel = config.formConfig.messageTextViewAccessibilityLabel
        return textView
    }()
    
    lazy var addScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.addScreenshotButtonAccessibilityLabel
        button.backgroundColor = config.theme.buttonBackground
        button.setTitleColor(config.theme.buttonForeground, for: .normal)
        button.addTarget(self, action: #selector(addScreenshotButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        button.layer.borderWidth = config.theme.outlineStyle.outlineWidth
        button.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        return button
    }()
    
    lazy var removeScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.removeScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.removeScreenshotButtonAccessibilityLabel
        button.backgroundColor = config.theme.buttonBackground
        button.setTitleColor(config.theme.buttonForeground, for: .normal)
        button.addTarget(self, action: #selector(removeScreenshotButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        button.layer.borderWidth = config.theme.outlineStyle.outlineWidth
        button.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.submitButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.submitButtonAccessibilityLabel
        button.backgroundColor = config.theme.submitBackground
        button.setTitleColor(config.theme.submitForeground, for: .normal)
        button.addTarget(self, action: #selector(submitFeedbackButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        button.layer.borderWidth = config.theme.outlineStyle.outlineWidth
        button.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
        return button
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.cancelButtonAccessibilityLabel
        button.backgroundColor = config.theme.buttonBackground
        button.setTitleColor(config.theme.buttonForeground, for: .normal)
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = config.theme.outlineStyle.cornerRadius
        button.layer.borderWidth = config.theme.outlineStyle.outlineWidth
        button.layer.borderColor = config.theme.outlineStyle.outlineColor.cgColor
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
        
        if self.config.formConfig.showName {
            inputStack.addArrangedSubview(self.fullNameLabel)
            inputStack.addArrangedSubview(self.fullNameTextField)
        }
        
        if self.config.formConfig.showEmail {
            inputStack.addArrangedSubview(self.emailLabel)
            inputStack.addArrangedSubview(self.emailTextField)
        }
        
        inputStack.addArrangedSubview(self.messageLabel)
        inputStack.addArrangedSubview(self.messageTextView)
        
        if self.config.formConfig.enableScreenshot {
            inputStack.addArrangedSubview(self.addScreenshotButton)
        }
        
        stack.addArrangedSubview(inputStack)
        
        let controlsStack = UIStackView()
        
        controlsStack.addArrangedSubview(self.submitButton)
        controlsStack.addArrangedSubview(self.cancelButton)
        stack.addArrangedSubview(controlsStack)
        
        [inputStack, controlsStack].forEach {
            $0.axis = .vertical
            $0.spacing = 8
        }
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }()
    
    lazy var scrollView = {
        let scrollView = UIScrollView(frame: view.bounds)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    // MARK: Helpers
    
    func fullLabelText(labelText: String, required: Bool) -> String {
        if required {
            return labelText + " " + config.formConfig.isRequiredLabel
        } else {
            return labelText
        }
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
