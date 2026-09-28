import SentrySampleShared
import SentrySwift
import UIKit

class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if !SentrySDK.isEnabled {
            SentrySDK.start { options in
                options.dsn = SentrySDKWrapper.defaultDSN
                options.debug = true
                SentrySDKWrapper.shared.configureDataCollection(options)
            }
        }

        view.backgroundColor = .systemBackground

        var configuration = UIButton.Configuration.borderedProminent()
        configuration.title = "Crash"
        configuration.baseBackgroundColor = .systemRed
        configuration.buttonSize = .large

        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(crash), for: .touchUpInside)

        var messageConfiguration = UIButton.Configuration.borderedProminent()
        messageConfiguration.title = "Capture Message"
        messageConfiguration.buttonSize = .large

        let messageButton = UIButton(configuration: messageConfiguration)
        messageButton.addTarget(self, action: #selector(captureMessage), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [button, messageButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func crash() {
        SentrySDK.crash()
    }

    @objc private func captureMessage() {
        SentrySDK.capture(message: "iOS-Swift-KeyboardExtension: Capture Message tapped")
    }
}
