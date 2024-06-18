import Sentry
import UIKit

class LoremIpsumViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dispatchQueue = DispatchQueue(label: "LoremIpsumViewController")
        dispatchQueue.async {
            if let path = Bundle.main.path(forResource: "LoremIpsum", ofType: "txt") {
                if let contents = FileManager.default.contents(atPath: path) {
                    DispatchQueue.main.async {
                        self.textView.text = String(data: contents, encoding: .utf8)
                        
                        dispatchQueue.asyncAfter(deadline: .now() + 0.1) {
                            SentrySDK.reportFullyDisplayed()
                        }
                    }
                }
            }
        }
    }
}
