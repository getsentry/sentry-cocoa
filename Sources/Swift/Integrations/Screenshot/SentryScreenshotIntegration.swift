internal import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

// We need to use a global variable because C doesn't allow capturing var
// nor we want to continue using the DependencyContainer
private weak var globalScreenshotSource: SentryScreenshotSource?

private let crashTimeScreenshotWriter: @convention(c) (UnsafePointer<CChar>) -> Void = { path in
    sentrykscrash_attachments_log("screenshot writer: enter")
    guard let source = globalScreenshotSource else {
        sentrykscrash_attachments_log("screenshot writer: source is nil")
        return
    }
    source.saveScreenShots(String(cString: path))
    sentrykscrash_attachments_log("screenshot writer: returned")
}

final class SentryScreenshotIntegration<Dependencies: ScreenshotIntegrationProvider>: NSObject, SwiftIntegration, SentryClientAttachmentProcessor {
    private let options: Options
    private let screenshotSource: SentryScreenshotSource
    private weak var client: SentryClientInternal?

    init?(with options: Options, dependencies: Dependencies) {
        guard options.attachScreenshot else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because attachScreenshot is disabled.")
            return nil
        }

        guard let screenshotSource = dependencies.screenshotSource else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because screenshotSource is not available.")
            return nil
        }

        self.options = options
        self.screenshotSource = screenshotSource

        super.init()

        if let client = SentrySDKInternal.currentHub().getClient() {
            self.client = client
            client.addAttachmentProcessor(self)
        }

        globalScreenshotSource = screenshotSource
        SentryDependencyContainer.sharedInstance().getKSCrashInstaller().setScreenshotProvider(
            crashTimeScreenshotWriter
        )
    }

    func uninstall() {
        globalScreenshotSource = nil
        SentryDependencyContainer.sharedInstance().getKSCrashInstaller().setScreenshotProvider(nil)
        client?.removeAttachmentProcessor(self)
    }

    static var name: String {
        "SentryScreenshotIntegration"
    }

    // MARK: - SentryClientAttachmentProcessor

    func processAttachments(_ attachments: [Attachment], for event: Event) -> [Attachment] {
        // We don't take screenshots if there is no exception/error.
        // We don't take screenshots if the event is a metric kit event.
        // Crash-time screenshots are written by the KSCrash attachments monitor.
        if (event.exceptions == nil && event.error == nil) || event.isFatalEvent {
            return attachments
        }

#if os(iOS) || os(visionOS)
        if event.isMetricKitEvent() {
            return attachments
        }
#endif

        #if !SDK_V10
        // If the event is an App hanging event, we can't take the
        // screenshot because the main thread is blocked.
        if event.isAppHangEvent {
            return attachments
        }
        #endif // !SDK_V10

        if let beforeCaptureScreenshot = options.beforeCaptureScreenshot,
           !beforeCaptureScreenshot(event) {
            return attachments
        }

        let screenshots = screenshotSource.appScreenshotDatasFromMainThread()

        let screenshotsAsAttachments = screenshots.enumerated().map { (index, data) in
            let name = index == 0 ? "screenshot.png" : "screenshot-\(index + 1).png"
            return Attachment(data: data, filename: name, contentType: "image/png")
        }
        return attachments + screenshotsAsAttachments
    }
}

#endif // SENTRY_TARGET_REPLAY_SUPPORTED
