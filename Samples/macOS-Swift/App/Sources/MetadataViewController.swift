import AppKit

class MetadataViewController: NSViewController {

    @IBOutlet weak var isAppSandboxActive: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Checks which are not changing during the app lifecycle can be done here.
        // Any check that can change over time should be done in other lifecycle methods.
        let isInAppSandbox = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        isAppSandboxActive.state = isInAppSandbox ? .on : .off
    }
}
