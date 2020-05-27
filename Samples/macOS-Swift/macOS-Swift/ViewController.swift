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
    
    @IBAction func addBreadCrumb(_ sender: Any) {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb: crumb)
    }
    
    @IBAction func captureMessage(_ sender: Any) {
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }

    @IBAction func crashOnException(_ sender: Any) {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        NSApp.perform("_crashOnException:", with: exception)
    }
    
    @IBAction func sentryCrash(_ sender: Any) {
        SentrySDK.crash()
    }
}
