import SentrySampleShared
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        SentrySDKWrapper.shared.startSentry()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        SentrySDKWrapper.shared.startSentry()
    }
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return contentText.count > 0
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.

        // Simulate processing the shared content
        processSharedContent { [weak self] _ in
            // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
            self?.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    // MARK: - Private Methods
    
    private func processSharedContent(completion: @escaping (Bool) -> Void) {
        // Simulate processing shared content
        // In a real implementation, this would handle different types of shared content
        
        guard let extensionContext = extensionContext else {
            completion(false)
            return
        }

        // Simulate async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
} 
