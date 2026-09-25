import Sentry
import UIKit

class ViewController: UIViewController {
    private let resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        resultLabel.text = "Waiting for capture"
        resultLabel.accessibilityIdentifier = "capture-result"
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            resultLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            resultLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: 50)
        ])

        SentrySDK.start { [weak self] options in
            // Use a local dummy DSN and drop events in beforeSend so this smoke test uploads nothing.
            options.dsn = "http://key@localhost:9000/456"
            options.enableMetricKit = false
            options.enableAutoSessionTracking = false
            options.sendClientReports = false
            options.beforeSend = { [weak self] event in
                if event.message?.formatted == "Static SDK smoke test" {
                    DispatchQueue.main.async { [weak self] in
                        self?.resultLabel.text = "Event prepared"
                    }
                }
                return nil
            }
        }
    }

    @IBAction func buttonTapped(_ sender: Any) {
        SentrySDK.capture(message: "Static SDK smoke test")
    }
}
