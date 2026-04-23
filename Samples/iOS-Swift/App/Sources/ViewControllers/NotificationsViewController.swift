import Sentry
import UIKit
import UserNotifications

class NotificationsViewController: UIViewController {

    private lazy var requestPermissionButton: UIButton = makeButton(title: "Enable Notifications", action: #selector(requestPermission))
    private lazy var sendTestNotificationButton: UIButton = makeButton(title: "Send Test Notification", action: #selector(sendTestNotification))

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .callout)
        return label
    }()

    private lazy var tokenLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.isHidden = true
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.text = "Note: the Notification Service Extension runs only for remote push notifications with mutable-content=1."
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [requestPermissionButton, sendTestNotificationButton, statusLabel, tokenLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack.forAutoLayout()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(apnsTokenReceived(_:)), name: .apnsTokenReceived, object: nil)
        refreshStatus()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshStatus()
        SentrySDK.reportFullyDisplayed()
    }

    @objc private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.setStatus("Error: \(error.localizedDescription)")
                    return
                }
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self?.refreshStatus()
            }
        }
    }

    @objc private func apnsTokenReceived(_ notification: Foundation.Notification) {
        if let token = notification.object as? String {
            tokenLabel.text = "APNs token:\n\(token)"
            tokenLabel.isHidden = false
        } else {
            tokenLabel.text = "APNs registration failed (expected on Simulator)"
            tokenLabel.isHidden = false
        }
    }

    @objc private func sendTestNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .authorized else {
                    self?.setStatus("Notifications not authorized.\nTap 'Enable Notifications' first.")
                    return
                }
                self?.scheduleLocalNotification()
            }
        }
    }

    private func scheduleLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sentry NSE Test"
        content.body = "NSE sample notification"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "io.sentry.nse-test", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.setStatus("Failed to schedule: \(error.localizedDescription)")
                } else {
                    self?.setStatus("✅ Notification scheduled in 3 seconds.")
                    SentrySDK.capture(message: "iOS-Swift: test notification scheduled")
                }
            }
        }
    }

    private func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let statusText: String
                switch settings.authorizationStatus {
                case .authorized: statusText = "✅ Notifications authorized"
                case .denied: statusText = "❌ Notifications denied"
                case .notDetermined: statusText = "⏳ Permission not requested"
                case .provisional: statusText = "⚠️ Provisional authorization"
                case .ephemeral: statusText = "⚠️ Ephemeral authorization"
                @unknown default: statusText = "Unknown status"
                }
                self?.setStatus(statusText)
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
