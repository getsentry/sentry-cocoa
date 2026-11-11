#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func crash(_ sender: Any) {
        SentrySDK.crash()
    }
    
}
