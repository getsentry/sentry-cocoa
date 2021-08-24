import Sentry
import UIKit

class LoremIpsumViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dispatchQueue = DispatchQueue(label: "LoremIpsumViewController")
        dispatchQueue.async {
            let span = SentrySDK.span?.startChild(operation: "io", description: "Read Lorem Ipsum")
            if let path = Bundle.main.path(forResource: "LoremIpsum", ofType: "txt") {
                if let contents = FileManager.default.contents(atPath: path) {
                    span?.finish(status: .ok)
                    DispatchQueue.main.async {
                        self.textView.text = String(data: contents, encoding: .utf8)
                    }
                }
            }
        }
    }

}
