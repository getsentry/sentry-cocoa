@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryExtendedAppLaunchManager {

    private let lock = NSLock()

    private var extendRequested = false
    private var extendTimestamp: Date?
    private var tracer: (any Span)?

    var isExtendRequested: Bool {
        lock.synchronized { extendRequested }
    }

    func extend() {
        lock.synchronized {
            if tracer != nil {
                SentrySDKLog.warning("extendAppLaunch() called after the app start transaction was already created. The app launch cannot be extended.")
                return
            }
            extendRequested = true
            extendTimestamp = Date()
        }
    }

    func storeTracer(_ tracer: any Span) {
        lock.synchronized {
            self.tracer = tracer
        }
    }

    func finish() {
        let (tracerToFinish, startTimestamp) = lock.synchronized { () -> (Span?, Date?) in
            guard let t = tracer, let ts = extendTimestamp else {
                return (nil, nil)
            }
            let result = (t as Span?, ts as Date?)
            tracer = nil
            extendTimestamp = nil
            extendRequested = false
            return result
        }

        guard let tracerToFinish, let startTimestamp else {
            SentrySDKLog.warning("finishExtendedAppLaunch() called but there is no extended app launch in progress.")
            return
        }

        let child = tracerToFinish.startChild(operation: SentrySpanOperationAppStart, description: "Extended App Start")
        child.startTimestamp = startTimestamp
        child.finish()

        tracerToFinish.finish()
    }

    func reset() {
        lock.synchronized {
            extendRequested = false
            extendTimestamp = nil
            tracer = nil
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
