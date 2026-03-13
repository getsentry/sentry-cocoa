import Sentry
import UIKit

class ViewController: UIViewController {
    @IBAction func buttonTapped(_ sender: Any) {
        DispatchQueue.global(qos: .utility).async {
            SentrySDK.capture(error: NSError(domain: "Swift 6 Test", code: -1))
        }
    }
}
