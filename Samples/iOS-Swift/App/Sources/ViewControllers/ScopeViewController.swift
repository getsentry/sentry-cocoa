import Sentry
import UIKit

// swiftlint:disable private_outlet
class ScopeViewController: UIViewController {
    
    @IBOutlet var attributesTextView: UITextView!
    @IBOutlet var attributeNameField: UITextField!
    @IBOutlet var attributeValueField: UITextField!

    private var testTransaction: Span?

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
    
    @IBAction func startTestTransaction(_ sender: Any?) {
        testTransaction = SentrySDK.startTransaction(
            name: "Scope Debug Span Flags",
            operation: "test.scope-debug",
            bindToScope: true
        )
        updateAttributesTextView()
    }

    @IBAction func finishTestTransaction(_ sender: Any?) {
        testTransaction?.finish()
        testTransaction = nil
        SentrySDK.configureScope { scope in
            scope.span = nil
        }
        updateAttributesTextView()
    }

    @IBAction func addFeatureFlag(_ sender: Any?) {
        guard let featureFlagName = featureFlagName else {
            return
        }

        SentrySDK.addFeatureFlag(name: featureFlagName, result: featureFlagResult)
        updateAttributesTextView()
    }

    @IBAction func removeFeatureFlag(_ sender: Any?) {
        guard let featureFlagName = featureFlagName else {
            return
        }

        SentrySDK.removeFeatureFlag(name: featureFlagName)
        updateAttributesTextView()
    }

    @IBAction func addSpanFeatureFlag(_ sender: Any?) {
        guard let featureFlagName = featureFlagName else {
            return
        }

        testTransaction?.addFeatureFlag(name: featureFlagName, result: featureFlagResult)
        updateAttributesTextView()
    }

    @IBAction func updateAttributesTextView(_ sender: Any?) {
        updateAttributesTextView()
    }
    
    private func updateAttributesTextView() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self else { return }

            let currentSpanData: Any
            if let currentSpan = SentrySDK.span {
                currentSpanData = currentSpan.serialize()
            } else {
                currentSpanData = "No active span"
            }
            let debugData: [String: Any] = [
                "scope": scope.serialize(),
                "currentSpan": currentSpanData
            ]
            guard let jsonData = try? JSONSerialization.data(
                withJSONObject: debugData,
                options: [.prettyPrinted]
            ) else {
                self.attributesTextView.text = "Error serializing scope and span to JSON"
                return
            }
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                self.attributesTextView.text = "Error converting scope and span data to JSON text"
                return
            }

            self.attributesTextView.text = jsonString
        }
    }

    private var featureFlagName: String? {
        guard let value = attributeNameField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
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
