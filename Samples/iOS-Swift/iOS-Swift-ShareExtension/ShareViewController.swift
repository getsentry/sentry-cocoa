import Sentry
import SentrySampleShared
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSentry()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupSentry()
    }

    private func setupSentry() {
        SentrySDKWrapper.shared.startSentry()
    }

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        SentrySDK.capture(message: "iOS-Swift-ShareExtension: didSelectPost called")
        
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
