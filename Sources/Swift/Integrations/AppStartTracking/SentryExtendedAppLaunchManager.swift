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

    /// Atomically checks if an extend was requested and stores the tracer if so.
    /// Returns `true` if the tracer was stored; `false` if caller should finish it.
    func storeTracerIfExtendRequested(_ tracer: any Span) -> Bool {
        lock.synchronized {
            guard extendRequested else {
                return false
            }
            self.tracer = tracer
            return true
        }
    }

    func finish() {
        let (tracerToFinish, startTimestamp) = lock.synchronized { () -> (Span?, Date?) in
            defer {
                tracer = nil
                extendTimestamp = nil
                extendRequested = false
            }
            guard let t = tracer, let ts = extendTimestamp else {
                return (nil, nil)
            }
            return (t as Span?, ts as Date?)
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
