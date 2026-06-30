@_implementationOnly import _SentryPrivate

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = AppHangTrackerProvider & ClientProvider & ThreadInspectorProvider & DebugImageProvider & HubProvider & ExtensionDetectorProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let appHangTracker: SentryAppHangTracker
    private let observer: SentryAppHangTrackerObserverToken

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            SentrySDKLog.debug("Not enabled, skipping installation")
            return nil
        }

        if let identifier = dependencies.extensionDetector.getExtensionPointIdentifier(), identifier.isDisabledExtensionPointIdentifier {
            SentrySDKLog.debug("Not enabling V3 hang tracking for extension: \(identifier)")
            return nil
        }

        SentrySDKLog.debug("Installing with threshold=\(options.experimental.appHangs.threshold)s")
        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.threshold) { hang in
            SentrySDKLog.debug("Observer callback — state=\(hang.state == .started ? "started" : "ended"), duration=\(hang.duration)s")
            guard hang.state == .ended else { return }
            guard let client = dependencies.client else {
                SentrySDKLog.debug("No client available, dropping hang event")
                return
            }

            let thread = SentryThread(threadId: NSNumber(value: 0))
            thread.name = "main"
            thread.crashed = NSNumber(value: false)
            thread.current = NSNumber(value: true)
            thread.isMain = NSNumber(value: true)

            let mechanism = Mechanism(type: "AppHang")
            mechanism.handled = NSNumber(value: true)
            mechanism.synthetic = NSNumber(value: true)

            let exception = Exception(
                value: "App hang detected: \(String(format: "%.1f", hang.duration)) sec",
                type: "App Hanging"
            )
            exception.mechanism = mechanism
            exception.threadId = NSNumber(value: 0)

            let event = Event(level: .warning)
            event.threads = [thread]
            event.exceptions = [exception]

            SentrySDKLog.debug("Capturing hang event (eventId=\(event.eventId.sentryIdString))")
            client.capture(event: event)
        }

        super.init()
    }

    func uninstall() {
        appHangTracker.removeObserver(token: observer)
    }

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}
