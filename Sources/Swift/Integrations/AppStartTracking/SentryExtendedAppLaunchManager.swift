@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryExtendedAppLaunchManager {

    private let lock = NSLock()

    private var extendRequested = false
    private var extendTimestamp: Date?
    private var tracer: (any Span)?
    private var appStartCreated = false

    var isExtendRequested: Bool {
        lock.synchronized { extendRequested }
    }

    func extend() {
        lock.synchronized {
            if appStartCreated {
                SentrySDKLog.warning("extendAppLaunch() called after the app start transaction was already created. The app launch cannot be extended.")
                return
            }
            SentrySDKLog.debug("Extending app launch")
            extendRequested = true
            extendTimestamp = Date()
        }
    }

    func markAppStartCreated() {
        lock.synchronized {
            SentrySDKLog.debug("Marking app start as created")
            appStartCreated = true
        }
    }

    /// Atomically checks if an extend was requested and stores the tracer if so.
    /// Returns `true` if the tracer was stored; `false` if caller should finish it.
    func storeTracerIfExtendRequested(_ tracer: any Span) -> Bool {
        lock.synchronized {
            guard extendRequested else {
                SentrySDKLog.debug("storeTracerIfExtendRequested() called but no extend was requested")
                return false
            }
            SentrySDKLog.debug("Storing tracer for extended app launch")
            self.tracer = tracer
            return true
        }
    }

    func finish() {
        let (tracerToFinish, startTimestamp, wasAppStartCreated) = lock.synchronized { () -> (Span?, Date?, Bool) in
            let created = appStartCreated
            defer {
                tracer = nil
                extendTimestamp = nil
                extendRequested = false
                appStartCreated = false
            }
            guard let t = tracer, let ts = extendTimestamp else {
                return (nil, nil, created)
            }
            return (t as Span?, ts as Date?, created)
        }

        guard let tracerToFinish, let startTimestamp else {
            if wasAppStartCreated {
                SentrySDKLog.warning("finishExtendedAppLaunch() called but the app start transaction was already completed. Call extendAppLaunch() before the app start transaction finishes.")
            } else {
                SentrySDKLog.warning("finishExtendedAppLaunch() called but there is no extended app launch in progress.")
            }
            return
        }

        SentrySDKLog.debug("Finishing extended app launch")
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
            appStartCreated = false
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
