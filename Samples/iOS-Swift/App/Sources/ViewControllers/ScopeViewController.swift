import Sentry
import UIKit

// swiftlint:disable private_outlet
class ScopeViewController: UIViewController {
    
    @IBOutlet var attributesTextView: UITextView!
    @IBOutlet var attributeNameField: UITextField!
    @IBOutlet var attributeValueField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        attributeNameField.text = "checkout_redesign"
        attributeValueField.text = "true"
        updateAttributesTextView()
    }

    @IBAction func setAttribute(_ sender: Any?) {
        guard let attributeName = attributeNameField.text, let attributeValue = attributeValueField.text else {
            return
        }
        
        SentrySDK.configureScope { scope in
            scope.setAttribute(value: attributeValue, key: attributeName)
        }
        
        updateAttributesTextView()
    }
    
    @IBAction func removeAttribute(_ sender: Any?) {
        guard let attributeName = attributeNameField.text else {
            return
        }
        
        SentrySDK.configureScope { scope in
            scope.removeAttribute(key: attributeName)
        }

        updateAttributesTextView()
    }
    
    @IBAction func addFeatureFlag(_ sender: Any?) {
        guard let featureFlagName = attributeNameField.text, !featureFlagName.isEmpty else {
            return
        }

        SentrySDK.addFeatureFlag(name: featureFlagName, result: featureFlagResult)
        updateAttributesTextView()
    }

    @IBAction func removeFeatureFlag(_ sender: Any?) {
        guard let featureFlagName = attributeNameField.text, !featureFlagName.isEmpty else {
            return
        }

        SentrySDK.removeFeatureFlag(name: featureFlagName)
        updateAttributesTextView()
    }

    @IBAction func updateAttributesTextView(_ sender: Any?) {
        updateAttributesTextView()
    }
    
    private func updateAttributesTextView() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self else { return }
            
            guard let jsonData = try? JSONSerialization.data(
                withJSONObject: scope.serialize(),
                options: [.prettyPrinted]
            ) else {
                self.attributesTextView.text = "Error serializing scope to JSON"
                return
            }
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                self.attributesTextView.text = "Error converting scope data to JSON text"
                return
            }

            self.attributesTextView.text = jsonString
        }
    }

    private var featureFlagResult: Bool {
        guard let value = attributeValueField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return true
        }

        switch value {
        case "false", "0", "no", "off":
            return false
        default:
            return true
        }
    }
}
