@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT

final class SentryViewHierarchyIntegration<Dependencies: ViewHierarchyIntegrationProvider>: NSObject, SwiftIntegration, SentryClientAttachmentProcessor {
    private let options: Options
    private let viewHierarchyProvider: SentryViewHierarchyProvider
    private weak var client: SentryClientInternal?

    init?(with options: Options, dependencies: Dependencies) {
        guard options.attachViewHierarchy else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because attachViewHierarchy is disabled.")
            return nil
        }

        guard let viewHierarchyProvider = dependencies.viewHierarchyProvider else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because viewHierarchyProvider is not available.")
            return nil
        }

        self.options = options
        self.viewHierarchyProvider = viewHierarchyProvider

        super.init()

        if let client = SentrySDKInternal.currentHub().getClient() {
            self.client = client
            client.addAttachmentProcessor(self)
        }

        viewHierarchyProvider.reportAccessibilityIdentifier = options.reportAccessibilityIdentifier
        
        sentrycrash_setSaveViewHierarchy { path in
            guard let path = path else { return }
            let reportPath = String(cString: path)
            let filePath = (reportPath as NSString).appendingPathComponent("view-hierarchy.json")
            SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.saveViewHierarchy(filePath)
        }
    }

    func uninstall() {
        sentrycrash_setSaveViewHierarchy(nil)
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

#if os(iOS) || targetEnvironment(macCatalyst)
        if event.isMetricKitEvent() {
            return attachments
        }
#endif

        // If the event is an App hanging event, we can't take the
        // view hierarchy because the main thread is blocked.
        if event.isAppHangEvent {
            return attachments
        }

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

#endif // (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
