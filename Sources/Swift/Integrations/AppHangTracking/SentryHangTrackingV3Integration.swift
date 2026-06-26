// Only gated for these platforms so we can use Combine
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_implementationOnly import _SentryPrivate
import Combine

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = AppHangTrackerProvider & ClientProvider & ThreadInspectorProvider & DebugImageProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let appHangTracker: SentryAppHangTracker
    private let observer: SentryAppHangTrackerObserverToken

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            return nil
        }

        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.appHangThreshold) { hang in
            guard let client = dependencies.client else {
                SentrySDKLog.debug("SentryHangTrackingV3Integration: No client available, dropping metric")
                return
            }

//            let mergedFrames = buildFlamegraphFrames(from: hang.stacktraces)
//            guard !mergedFrames.isEmpty else { return }
//
//            let stacktrace = SentryStacktrace(frames: mergedFrames, registers: [:])
//            stacktrace.snapshot = NSNumber(value: true)
//
            let thread = SentryThread(threadId: NSNumber(value: 0))
            thread.name = "main"
            thread.crashed = NSNumber(value: false)
            thread.current = NSNumber(value: true)
            thread.isMain = NSNumber(value: true)
//            thread.stacktrace = stacktrace

            let mechanism = Mechanism(type: "mx_hang_diagnostic")
            mechanism.handled = NSNumber(value: true)
            mechanism.synthetic = NSNumber(value: true)

            let exception = Exception(
                value: "App hang detected: \(String(format: "%.1f", hang.duration)) sec",
                type: "MXHangDiagnostic"
            )
            exception.mechanism = mechanism
//            exception.stacktrace = stacktrace
            exception.threadId = NSNumber(value: 0)

            let event = Event(level: .warning)
            event.threads = [thread]
            event.exceptions = [exception]
//            event.debugMeta = dependencies.debugImageProvider.getDebugImagesFromCacheForThreads(threads: [thread])

            client.capture(event: event)
        }

        super.init()
    }

    func uninstall() {}

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}
#endif
