@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryExtendedAppLaunchManager {

    private let lock = NSLock()

    private var extendRequested = false
    private var extendTimestamp: Date?
    private var tracer: (any Span)?
    private var tracerConfiguration: SentryTracerConfiguration?
    private var extendedSpan: (any Span)?
    private var appStartCreated = false

    var isExtendRequested: Bool {
        lock.synchronized { extendRequested }
    }

    @discardableResult
    func extend() -> (any Span)? {
        let timestamp: Date? = lock.synchronized {
            if appStartCreated {
                SentrySDKLog.warning("extendAppLaunch() called after the app start transaction was already created. The app launch cannot be extended.")
                return nil
            }
            SentrySDKLog.debug("Extending app launch")
            extendRequested = true
            extendTimestamp = Date()
            return extendTimestamp
        }

        guard let timestamp else { return nil }

        guard SentrySDK.isEnabled else {
            SentrySDKLog.warning("extendAppLaunch() called before starting the SDK. Call SentrySDK.start(options:) first.")
            lock.synchronized {
                extendRequested = false
                extendTimestamp = nil
            }
            return nil
        }

        let config = SentryTracerConfiguration(block: { c in
            c.waitForChildren = true
        })

        let newTracer = StandaloneTransactionStrategy.createTracer(configuration: config)

        let child = newTracer.startChild(
            operation: SentrySpanOperationAppStart,
            description: "Extended App Start"
        )
        child.startTimestamp = timestamp

        lock.synchronized {
            self.tracer = newTracer
            self.tracerConfiguration = config
            self.extendedSpan = child
        }

        return child
    }

    func markAppStartCreated() {
        lock.synchronized {
            SentrySDKLog.debug("Marking app start as created")
            appStartCreated = true
        }
    }

    func setAppStartMeasurement(_ measurement: SentryAppStartMeasurement) {
        let tracerToFinish: (any Span)? = lock.synchronized {
            tracerConfiguration?.appStartMeasurement = measurement
            SentryAppStartMeasurementProvider.markAsRead()
            return tracer
        }
        tracerToFinish?.finish()
    }

    /// Returns `true` if the tracer was already created by `extend()`;
    /// `false` if the caller should create and finish its own tracer.
    func isTracerAlreadyCreated() -> Bool {
        lock.synchronized { tracer != nil }
    }

    func finish() {
        let spanToFinish: (any Span)? = lock.synchronized {
            defer {
                extendedSpan = nil
                extendRequested = false
                extendTimestamp = nil
            }
            guard extendedSpan != nil else {
                if appStartCreated {
                    SentrySDKLog.warning("finishExtendedAppLaunch() called but the app start transaction was already completed. Call extendAppLaunch() before the app start transaction finishes.")
                } else {
                    SentrySDKLog.warning("finishExtendedAppLaunch() called but there is no extended app launch in progress.")
                }
                return nil
            }
            return extendedSpan
        }

        guard let spanToFinish else { return }

        SentrySDKLog.debug("Finishing extended app launch")
        spanToFinish.finish()
    }

    func reset() {
        lock.synchronized {
            extendRequested = false
            extendTimestamp = nil
            tracer = nil
            tracerConfiguration = nil
            extendedSpan = nil
            appStartCreated = false
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
