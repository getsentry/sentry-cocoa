import Sentry
import UIKit

class MetricsViewController: UIViewController {

    // MARK: - Interface Builder Outlets

    @IBOutlet weak var counterTextField: UITextField!
    @IBOutlet weak var distributionTextField: UITextField!
    @IBOutlet weak var gaugeTextField: UITextField!

    // MARK: - Interface Builder Actions

    @IBAction func addCountAction(_ sender: UIButton) {
        guard let value = Int(counterTextField.text ?? "0") else { return }
        SentrySDK.metrics.count(key: "sample.counter", value: value)
    }

    @IBAction func addDistributionAction(_ sender: UIButton) {
        guard let value = Double(distributionTextField.text ?? "0") else { return }
        SentrySDK.metrics.distribution(key: "sample.distribution", value: value)
    }

    @IBAction func addGaugeAction(_ sender: UIButton) {
        guard let value = Double(gaugeTextField.text ?? "0") else { return }
        SentrySDK.metrics.gauge(key: "sample.distribution", value: value)
    }
}
