#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate

/// Routes the process-lifetime swizzles and ``SentryWebViewTracing`` to the refresher of the
/// current SDK lifecycle.
final class SentryWebViewTraceRefresherProxy {
    private final class WeakBox {
        weak var value: SentryWebViewTraceRefresher?

        init(_ value: SentryWebViewTraceRefresher) {
            self.value = value
        }
    }

    static let shared = SentryWebViewTraceRefresherProxy()

    private let weakTargetMutex = SentryMutex<WeakBox?>(nil)

    var target: SentryWebViewTraceRefresher? {
        weakTargetMutex.withLock { $0?.value }
    }

    func setTarget(_ target: SentryWebViewTraceRefresher) {
        let reference = WeakBox(target)
        weakTargetMutex.withLock { $0 = reference }
    }

    func removeTarget(_ target: SentryWebViewTraceRefresher) {
        weakTargetMutex.withLock {
            // An older integration must not remove a newer integration's refresher.
            guard $0?.value === target else {
                return
            }
            $0 = nil
        }
    }
}
#endif
