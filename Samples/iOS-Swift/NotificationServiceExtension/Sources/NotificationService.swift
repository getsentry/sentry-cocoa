import Sentry
@_spi(Private) import Sentry
import SentrySampleShared
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        setupSentry()
        // Wait 1 second to ensure sentry is loaded
        sleep(1)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        SentrySDK.capture(message: "iOS-Swift-NotificationServiceExtension: didReceive called")

        bestAttemptContent.body = """
        Sentry Enabled: \(isSentryEnabled ? "✅" : "❌")
        ANR Not Installed: \(!isANRInstalled ? "✅" : "❌")
        Watchdog Not Installed: \(!isWatchdogInstalled ? "✅" : "❌")
        """

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }

    private func setupSentry() {
        guard !SentrySDK.isEnabled else { return }

        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true

            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
        }
    }

    var isANRInstalled: Bool {
        isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    var isWatchdogInstalled: Bool {
        isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("WatchdogTerminationTracking")
    }

    var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }
}
