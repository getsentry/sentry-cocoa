@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Determines how a completed app start measurement is reported to Sentry.
protocol AppStartReportingStrategy {
    func report(_ measurement: SentryAppStartMeasurement, traceId: SentryId)
    func shouldSkipMaxAppStartDurationLimit() -> Bool
}

/// Attaches app start data to the first UIViewController transaction (default behavior).
struct AttachToTransactionStrategy: AppStartReportingStrategy {
    func report(_ measurement: SentryAppStartMeasurement, traceId: SentryId) {
        SentrySDKInternal.setAppStartMeasurement(measurement)
    }

    func shouldSkipMaxAppStartDurationLimit() -> Bool {
        return false
    }
}

/// Sends a standalone app start transaction by passing the measurement directly via the tracer
/// configuration. The existing tracer pipeline then handles span building, measurements, context,
/// debug images, and profiling.
struct StandaloneTransactionStrategy: AppStartReportingStrategy {

    private enum Constants {
        static let appStartTransactionName = "App Start"
    }

    let extendedAppLaunchManager: SentryExtendedAppLaunchManager

    static func createTracer(
        traceId: SentryId = SentryId(),
        configuration: SentryTracerConfiguration
    ) -> any Span {
        let context = TransactionContext(
            name: Constants.appStartTransactionName,
            rawNameSource: SentryTransactionNameSource.component.rawValue,
            operation: SentrySpanOperationAppStart,
            origin: SentryTraceOriginAutoAppStart,
            trace: traceId
        )

        let hub = SentrySDKInternal.currentHub()
        return hub.startTransaction(
            with: context,
            bindToScope: false,
            customSamplingContext: [:],
            configuration: configuration
        )
    }

    func report(_ measurement: SentryAppStartMeasurement, traceId: SentryId) {
        guard SentrySDK.isEnabled else {
            SentrySDKLog.warning("SDK is not enabled, dropping standalone app start transaction")
            return
        }

        defer {
            extendedAppLaunchManager.markAppStartCreated()
        }

        if extendedAppLaunchManager.isTracerAlreadyCreated() {
            extendedAppLaunchManager.setAppStartMeasurement(measurement)
            return
        }

        let configuration = SentryTracerConfiguration(block: { config in
            config.appStartMeasurement = measurement
            SentryAppStartMeasurementProvider.markAsRead()
        })

        let tracer = Self.createTracer(traceId: traceId, configuration: configuration)
        tracer.finish()
    }

    func shouldSkipMaxAppStartDurationLimit() -> Bool {
        return true
    }
}

/// Helper to identify standalone app start transactions from ObjC code.
@_spi(Private) @objc public final class StandaloneAppStartTransactionHelper: NSObject {
    /// Returns `true` when the operation and origin match a standalone app start transaction.
    @objc public static func isStandaloneAppStartTransaction(operation: String, origin: String) -> Bool {
        return operation == SentrySpanOperationAppStart && origin == SentryTraceOriginAutoAppStart
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
