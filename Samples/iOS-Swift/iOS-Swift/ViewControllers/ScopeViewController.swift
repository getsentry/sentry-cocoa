import Sentry
import UIKit

class ScopeViewController: UIViewController {
    
    @IBOutlet var attributesTextView: UITextView!
    @IBOutlet var attributeNameField: UITextField!
    @IBOutlet var attributeValueField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

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
    
    @IBAction func updateAttributesTextView(_ sender: Any?) {
        updateAttributesTextView()
    }
    
    private func updateAttributesTextView() {
        SentrySDK.configureScope { [weak self] scope in
            guard let self else { return }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: scope.attributes, options: [.prettyPrinted]) else {
                self.attributesTextView.text = "Error serializing attributes to JSON"
                return
            }
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                self.attributesTextView.text = "Error converting data to JSON text"
                return
            }

            self.attributesTextView.text = jsonString
        }
    }
}
