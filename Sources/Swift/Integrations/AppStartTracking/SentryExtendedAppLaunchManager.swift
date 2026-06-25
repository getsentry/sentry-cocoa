@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryExtendedAppLaunchManager {
    
    enum Constants {
        static let extendedOperation = "\(SentrySpanOperationAppStart).extended"
    }

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

    func extend() {
        let (timestamp, config): (Date?, SentryTracerConfiguration?) = lock.synchronized {
            if appStartCreated {
                SentrySDKLog.warning("extendAppStart() called after the app start transaction was already created. The app launch cannot be extended.")
                return (nil, nil)
            }
            guard extendedSpan == nil else {
                SentrySDKLog.debug("extendAppStart() already called")
                return (nil, nil)
            }
            SentrySDKLog.debug("Extending app launch")
            extendRequested = true
            extendTimestamp = Date()

            let c = SentryTracerConfiguration(block: { c in
                c.waitForChildren = true
            })
            self.tracerConfiguration = c
            return (extendTimestamp, c)
        }

        guard let timestamp, let config else { return }

        guard SentrySDK.isEnabled else {
            SentrySDKLog.warning("extendAppStart() called before starting the SDK. Call SentrySDK.start(options:) first.")
            lock.synchronized {
                extendRequested = false
                extendTimestamp = nil
                tracerConfiguration = nil
            }
            return
        }

        let traceId = SentryAppStartMeasurementProvider.appStartTraceId() ?? SentryId()
        let newTracer = StandaloneTransactionStrategy.createTracer(traceId: traceId, configuration: config)

        let child = newTracer.startChild(
            operation: Constants.extendedOperation,
            description: "Extended App Start"
        )
        child.startTimestamp = timestamp

        let shouldFinishTracer: Bool = lock.synchronized {
            self.tracer = newTracer
            self.extendedSpan = child
            config.appStartMeasurement?.extendedAppStartSpan = child
            return config.appStartMeasurement != nil
        }

        if shouldFinishTracer {
            SentrySDKLog.debug("App start measurement was already set, finishing tracer")
            newTracer.finish()
        }
    }

    func extendedAppStartSpan() -> (any Span)? {
        lock.synchronized { extendedSpan }
    }

    func markAppStartCreated() {
        lock.synchronized {
            SentrySDKLog.debug("Marking app start as created")
            appStartCreated = true
        }
    }

    func setAppStartMeasurement(_ measurement: SentryAppStartMeasurement) {
        SentrySDKLog.debug("Setting app start measurement on extended launch tracer")
        let tracerToFinish: (any Span)? = lock.synchronized {
            tracerConfiguration?.appStartMeasurement = measurement
            measurement.extendedAppStartSpan = extendedSpan
            SentryAppStartMeasurementProvider.markAsRead()
            return tracer
        }
        if tracerToFinish != nil {
            SentrySDKLog.debug("Finishing extended app launch tracer after measurement set")
        }
        tracerToFinish?.finish()
    }

    /// Returns `true` if `extend()` was called and reserved the tracer;
    /// `false` if the caller should create and finish its own tracer.
    func isTracerAlreadyCreated() -> Bool {
        lock.synchronized { tracerConfiguration != nil }
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
                    SentrySDKLog.warning("finishExtendedAppStart() called but the app start transaction was already completed. Call extendAppStart() before the app start transaction finishes.")
                } else {
                    SentrySDKLog.warning("finishExtendedAppStart() called but there is no extended app launch in progress.")
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
