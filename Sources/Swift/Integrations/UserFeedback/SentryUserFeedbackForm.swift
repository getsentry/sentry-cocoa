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
        layoutUI(config)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    func addScreenshotButtonTapped() {
        
    }
    
    func submitFeedbackButtonTapped() {
        // ???: marshal data how?
        delegate?.confirmed()
    }
    
    func cancelButtonTapped() {
        delegate?.cancelled()
    }
    
    // MARK: UI
    
    lazy var fullNameLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.nameLabel
        return label
    }()
    
    lazy var fullNameTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.namePlaceholder
        field.borderStyle = .roundedRect
        return field
    }()
    
    lazy var emailLabel = {
        let label = UILabel(frame: .zero)
        label.text = config.formConfig.emailLabel
        return label
    }()
    
    lazy var emailTextField = {
        let field = UITextField(frame: .zero)
        field.placeholder = config.formConfig.emailPlaceholder
        field.borderStyle = .roundedRect
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
        return textView
    }()
    
    lazy var screenshotButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.addScreenshotButtonLabel, for: .normal)
        button.backgroundColor = .systemBlue
        button.addTarget(self, action: #selector(addScreenshotButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var submitButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.confirmButtonLabel, for: .normal)
        button.backgroundColor = .systemGreen
        button.addTarget(self, action: #selector(submitFeedbackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var cancelButton = {
        let button = UIButton(frame: .zero)
        button.setTitle(config.formConfig.cancelButtonLabel, for: .normal)
        button.backgroundColor = .systemRed
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    func layoutUI(_ config: SentryUserFeedbackConfiguration) {
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView(arrangedSubviews: [fullNameLabel, fullNameTextField, emailLabel, emailTextField, messageLabel, messageTextView, screenshotButton, submitButton, cancelButton])
        stackView.axis = .vertical
        stackView.spacing = 8
        
        let scrollView = UIScrollView(frame: view.bounds)
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.spacing),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: config.spacing),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -config.spacing),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.spacing),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            messageTextView.heightAnchor.constraint(equalToConstant: config.theme.font.lineHeight * 5)
        ])
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
