import Sentry
@_spi(Private) @testable import Sentry
import SentrySampleShared
import UIKit
import UniformTypeIdentifiers

class ActionViewController: UIViewController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSentry()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupSentry()
    }

    private func setupSentry() {
        // Prevent double initialization - SentrySDK.start() can be called multiple times
        // but we want to avoid unnecessary re-initialization
        guard !SentrySDK.isEnabled else {
            return
        }

        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true

            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    func setupUI() {
        view.backgroundColor = .systemBackground

        setupDoneButton()
        setupStatusChecklist()
    }

    var isANRInstalled: Bool {
        return isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }

    // MARK: - UI

    func setupDoneButton() {
        var configuration = UIButton.Configuration.borderedProminent()
        configuration.title = "Done"
        configuration.baseBackgroundColor = .systemBlue
        configuration.buttonSize = .large

        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(doneAction(_:)), for: .touchUpInside)
        view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    @objc func doneAction(_ sender: UIButton) {
        SentrySDK.capture(message: "iOS-Swift-ActionExtension: done called")
        let returnItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        extensionContext?.completeRequest(returningItems: returnItems, completionHandler: nil)
    }

    func setupStatusChecklist() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        view.addSubview(stack)

        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let sdkStatusLabel = UILabel()
        sdkStatusLabel.text = isSentryEnabled ? "✅ Sentry is enabled" : "❌ Sentry is not enabled"
        sdkStatusLabel.textAlignment = .center
        stack.addArrangedSubview(sdkStatusLabel)

        let anrStatusLabel = UILabel()
        // We want the ANR integration to be disabled for share extensions due to false-positives
        anrStatusLabel.text = !isANRInstalled ? "✅ ANR Tracking not installed" : "❌ ANR Tracking installed"
        anrStatusLabel.textAlignment = .center
        stack.addArrangedSubview(anrStatusLabel)
    }
}
