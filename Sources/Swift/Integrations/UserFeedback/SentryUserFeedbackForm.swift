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
            
            messageTextView.heightAnchor.constraint(equalToConstant: config.theme.font.lineHeight * 5)
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
        field.borderStyle = .roundedRect
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
        field.borderStyle = .roundedRect
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
        textView.layer.borderWidth = 0.3
        textView.layer.borderColor = UIColor(white: 204 / 255, alpha: 1).cgColor // this is the observed color of a textfield outline when using borderStyle = .roundedRect
        textView.layer.cornerRadius = 5
        textView.accessibilityLabel = config.formConfig.messageTextViewAccessibilityLabel
        return textView
    }()
    
    lazy var addScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.addScreenshotButtonAccessibilityLabel
        button.backgroundColor = .systemBlue
        button.addTarget(self, action: #selector(addScreenshotButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var removeScreenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.removeScreenshotButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.removeScreenshotButtonAccessibilityLabel
        button.backgroundColor = .systemBlue
        button.addTarget(self, action: #selector(removeScreenshotButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.submitButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.submitButtonAccessibilityLabel
        button.backgroundColor = .systemGreen
        button.addTarget(self, action: #selector(submitFeedbackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.accessibilityLabel = config.formConfig.cancelButtonAccessibilityLabel
        button.backgroundColor = .systemRed
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
        stack.spacing = 8
        
        stack.addArrangedSubview(headerStack)
        
        if self.config.formConfig.showName {
            stack.addArrangedSubview(self.fullNameLabel)
            stack.addArrangedSubview(self.fullNameTextField)
        }
        
        if self.config.formConfig.showEmail {
            stack.addArrangedSubview(self.emailLabel)
            stack.addArrangedSubview(self.emailTextField)
        }
        
        stack.addArrangedSubview(self.messageLabel)
        stack.addArrangedSubview(self.messageTextView)
        
        if self.config.formConfig.enableScreenshot {
            stack.addArrangedSubview(self.addScreenshotButton)
        }
        
        stack.addArrangedSubview(self.submitButton)
        stack.addArrangedSubview(self.cancelButton)
        
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
