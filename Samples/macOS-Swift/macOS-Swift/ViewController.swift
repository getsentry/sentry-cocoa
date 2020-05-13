import Cocoa
import Sentry

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func crashOnException(_ sender: Any) {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        NSApp.perform("_crashOnException:", with: exception)
    }
    
    @IBAction func sentryCrash(_ sender: Any) {
        SentrySDK.crash()
    }
}
