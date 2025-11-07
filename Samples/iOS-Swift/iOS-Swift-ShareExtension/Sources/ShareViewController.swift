@_spi(Private) @testable import Sentry
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
        // Prevent double initialization - SentrySDK.start() can be called multiple times
        // but we want to avoid unnecessary re-initialization
        guard !SentrySDK.isEnabled else {
            return
        }

        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true

            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
        }
    }

    override func isContentValid() -> Bool {
        // We are not actually processing any information, therefore just allow all content
        return true
    }

    override func didSelectPost() {
        SentrySDK.capture(message: "iOS-Swift-ShareExtension: didSelectPost called")
        
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        guard let isSDKEnabledItem = SLComposeSheetConfigurationItem() else {
            return []
        }
        isSDKEnabledItem.title = "Sentry Enabled?"
        isSDKEnabledItem.value = isSentryEnabled ? "✅" : "❌"

        guard let isANRActiveItem = SLComposeSheetConfigurationItem() else {
            return []
        }
        isANRActiveItem.title = "ANR Disabled?"
        // We want the ANR integration to be disabled for share extensions due to false-positives
        isANRActiveItem.value = !isANRInstalled ? "✅" : "❌"

        return [
            isSDKEnabledItem,
            isANRActiveItem
        ]
    }

    var isANRInstalled: Bool {
        return isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }
}
