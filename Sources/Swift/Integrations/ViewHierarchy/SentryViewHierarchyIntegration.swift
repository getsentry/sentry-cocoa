internal import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias SentryViewHierarchyIntegrationProvider = ViewHierarchyProviderProvider & ClientProvider

// We need to use a global variable because C doesn't allow capturing var
// nor we want to continue using the DependencyContainer
private weak var globalViewHierarchyProvider: SentryViewHierarchyProvider?

#if SENTRY_DISABLE_SENTRYCRASH_V10
private let crashTimeViewHierarchyWriter: @convention(c) (UnsafePointer<CChar>) -> Void = { path in
    sentrykscrash_attachments_log("view-hierarchy writer: enter")
    guard let provider = globalViewHierarchyProvider else {
        sentrykscrash_attachments_log("view-hierarchy writer: provider is nil")
        return
    }
    let filePath = (String(cString: path) as NSString).appendingPathComponent("view-hierarchy.json")
    provider.saveViewHierarchy(filePath)
    sentrykscrash_attachments_log("view-hierarchy writer: returned")
}
#endif

final class SentryViewHierarchyIntegration<Dependencies: SentryViewHierarchyIntegrationProvider>: NSObject, SwiftIntegration, SentryClientAttachmentProcessor {
    private let options: Options
    private let viewHierarchyProvider: SentryViewHierarchyProvider
    private weak var client: SentryClientInternal?

    init?(with options: Options, dependencies: Dependencies) {
        guard options.attachViewHierarchy else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because attachViewHierarchy is disabled.")
            return nil
        }

        guard let viewHierarchyProvider = dependencies.viewHierarchyProvider else {
            SentrySDKLog.warning("Not going to enable \(Self.name) because viewHierarchyProvider is not available.")
            return nil
        }

        self.options = options
        self.viewHierarchyProvider = viewHierarchyProvider

        guard let client = dependencies.client else {
            SentrySDKLog.warning("Not going to enable \(Self.name) because client is not available.")
            return nil
        }
        self.client = client

        super.init()

        viewHierarchyProvider.reportAccessibilityIdentifier = options.reportAccessibilityIdentifier
        client.addAttachmentProcessor(self)

        globalViewHierarchyProvider = viewHierarchyProvider
#if !SENTRY_DISABLE_SENTRYCRASH_V10
        sentrycrash_setSaveViewHierarchy { path in
            guard let path = path else { return }
            let reportPath = String(cString: path)
            let filePath = (reportPath as NSString).appendingPathComponent("view-hierarchy.json")
            globalViewHierarchyProvider?.saveViewHierarchy(filePath)
        }
#else
        SentryDependencyContainer.sharedInstance().getKSCrashInstaller().setViewHierarchyProvider(
            crashTimeViewHierarchyWriter
        )
#endif
    }

    func uninstall() {
        globalViewHierarchyProvider = nil
#if !SENTRY_DISABLE_SENTRYCRASH_V10
        sentrycrash_setSaveViewHierarchy(nil)
#else
        SentryDependencyContainer.sharedInstance().getKSCrashInstaller().setViewHierarchyProvider(nil)
#endif
        client?.removeAttachmentProcessor(self)
    }

    static var name: String {
        "SentryViewHierarchyIntegration"
    }

    // MARK: - SentryClientAttachmentProcessor

    func processAttachments(_ attachments: [Attachment], for event: Event) -> [Attachment] {
        // We don't attach the view hierarchy if there is no exception/error.
        // We don't attach the view hierarchy if the event is a crash or metric kit event.
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
        // view hierarchy because the main thread is blocked.
        if event.isAppHangEvent {
            return attachments
        }
        #endif // !SDK_V10

        if let beforeCaptureViewHierarchy = options.beforeCaptureViewHierarchy,
           !beforeCaptureViewHierarchy(event) {
            return attachments
        }

        guard let viewHierarchy = viewHierarchyProvider.appViewHierarchyFromMainThread() else {
            return attachments
        }

        let attachment = Attachment(
            data: viewHierarchy,
            filename: "view-hierarchy.json",
            contentType: "application/json",
            attachmentType: .viewHierarchy
        )

        return attachments + [attachment]
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
