@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryExtendedAppLaunchManager {
    
    enum Constants {
        static let extendedOperation = "\(SentrySpanOperationAppStart).extended"
    }

    private struct State {
        var extendRequested = false
        var extendTimestamp: Date?
        var tracer: (any Span)?
        var tracerConfiguration: SentryTracerConfiguration?
        var extendedSpan: (any Span)?
        var appStartCreated = false
    }

    private let state = SentryMutex(State())

    var isExtendRequested: Bool {
        state.withLock { $0.extendRequested }
    }

    func extend() {
        let (timestamp, config): (Date?, SentryTracerConfiguration?) = state.withLock {
            if $0.appStartCreated {
                SentrySDKLog.warning("extendAppStart() called after the app start transaction was already created. The app launch cannot be extended.")
                return (nil, nil)
            }
            guard $0.extendedSpan == nil else {
                SentrySDKLog.debug("extendAppStart() already called")
                return (nil, nil)
            }
            SentrySDKLog.debug("Extending app launch")
            $0.extendRequested = true
            $0.extendTimestamp = Date()

            let c = SentryTracerConfiguration(block: { c in
                c.waitForChildren = true
            })
            $0.tracerConfiguration = c
            return ($0.extendTimestamp, c)
        }

        guard let timestamp, let config else { return }

        guard SentrySDK.isEnabled else {
            SentrySDKLog.warning("extendAppStart() called before starting the SDK. Call SentrySDK.start(options:) first.")
            state.withLock {
                $0.extendRequested = false
                $0.extendTimestamp = nil
                $0.tracerConfiguration = nil
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

        let shouldFinishTracer: Bool = state.withLock {
            $0.tracer = newTracer
            $0.extendedSpan = child
            config.appStartMeasurement?.extendedAppStartSpan = child
            return config.appStartMeasurement != nil
        }

        if shouldFinishTracer {
            SentrySDKLog.debug("App start measurement was already set, finishing tracer")
            newTracer.finish()
        }
    }

    func extendedAppStartSpan() -> (any Span)? {
        state.withLock { $0.extendedSpan }
    }

    func markAppStartCreated() {
        state.withLock {
            SentrySDKLog.debug("Marking app start as created")
            $0.appStartCreated = true
        }
    }

    func setAppStartMeasurement(_ measurement: SentryAppStartMeasurement) {
        SentrySDKLog.debug("Setting app start measurement on extended launch tracer")
        let tracerToFinish: (any Span)? = state.withLock {
            $0.tracerConfiguration?.appStartMeasurement = measurement
            measurement.extendedAppStartSpan = $0.extendedSpan
            SentryAppStartMeasurementProvider.markAsRead()
            return $0.tracer
        }
        if tracerToFinish != nil {
            SentrySDKLog.debug("Finishing extended app launch tracer after measurement set")
        }
        tracerToFinish?.finish()
    }

    /// Returns `true` if `extend()` was called and reserved the tracer;
    /// `false` if the caller should create and finish its own tracer.
    func isTracerAlreadyCreated() -> Bool {
        state.withLock { $0.tracerConfiguration != nil }
    }

    func finish() {
        let spanToFinish: (any Span)? = state.withLock { (state: inout State) -> (any Span)? in
            defer {
                state.extendedSpan = nil
                state.extendRequested = false
                state.extendTimestamp = nil
            }
            guard state.extendedSpan != nil else {
                if state.appStartCreated {
                    SentrySDKLog.warning("finishExtendedAppStart() called but the app start transaction was already completed. Call extendAppStart() before the app start transaction finishes.")
                } else {
                    SentrySDKLog.warning("finishExtendedAppStart() called but there is no extended app launch in progress.")
                }
                return nil
            }
            return state.extendedSpan
        }

        guard let spanToFinish else { return }

        SentrySDKLog.debug("Finishing extended app launch")
        spanToFinish.finish()
    }

    func reset() {
        state.withLock {
            $0.extendRequested = false
            $0.extendTimestamp = nil
            $0.tracer = nil
            $0.tracerConfiguration = nil
            $0.extendedSpan = nil
            $0.appStartCreated = false
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
