import ContactProvider
import UIKit

/// Enables the Contact Provider extension, which the system then launches in the background.
///
/// The extension reports the state of the SDK as contacts of the organization "Sentry Contact Provider"
/// in the Contacts app.
class ContactProviderViewController: UIViewController {

    private static let unavailableMessage = "Contact Provider extensions require iOS 18"

    private lazy var enableButton: UIButton = makeButton(title: "Enable Contact Provider", action: #selector(enableProvider))
    private lazy var syncButton: UIButton = makeButton(title: "Sync Contacts", action: #selector(syncContacts))
    private lazy var disableButton: UIButton = makeButton(title: "Disable Contact Provider", action: #selector(disableProvider))

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .callout)
        label.accessibilityIdentifier = "contact-provider-status"
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.text = "Note: after enabling, open the Contacts app and look for the contacts of \"Sentry Contact Provider\". They show whether the SDK installed app hang and watchdog termination tracking in the extension."
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [enableButton, syncButton, disableButton, statusLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack.forAutoLayout()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Contact Provider"
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        refreshStatus()
    }

    @objc private func enableProvider() {
        guard #available(iOS 18.0, *) else { return setStatus(Self.unavailableMessage) }
        run(successMessage: "✅ Contact Provider enabled") { manager in
            try await manager.enable()
            try await manager.signalEnumerator()
        }
    }

    @objc private func syncContacts() {
        guard #available(iOS 18.0, *) else { return setStatus(Self.unavailableMessage) }
        run(successMessage: "✅ Sync requested") { manager in
            try await manager.signalEnumerator()
        }
    }

    @objc private func disableProvider() {
        guard #available(iOS 18.0, *) else { return setStatus(Self.unavailableMessage) }
        run(successMessage: "Contact Provider disabled") { manager in
            try await manager.disable()
        }
    }

    private func refreshStatus() {
        guard #available(iOS 18.0, *) else { return setStatus(Self.unavailableMessage) }
        do {
            let manager = try ContactProviderManager()
            setStatus(manager.isEnabled ? "✅ Contact Provider enabled" : "⏳ Contact Provider not enabled")
        } catch {
            setStatus("Error: \(error.localizedDescription)")
        }
    }

    @available(iOS 18.0, *)
    private func run(successMessage: String, _ operation: @escaping (ContactProviderManager) async throws -> Void) {
        Task { @MainActor [weak self] in
            do {
                try await operation(try ContactProviderManager())
                self?.setStatus(successMessage)
            } catch {
                self?.setStatus("Error: \(error.localizedDescription)")
            }
        }
    }

    private func setStatus(_ text: String) {
        statusLabel.text = text
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
