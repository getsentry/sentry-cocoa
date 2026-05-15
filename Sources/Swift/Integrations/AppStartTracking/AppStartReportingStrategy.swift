@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Determines how a completed app start measurement is reported to Sentry.
protocol AppStartReportingStrategy {
    func report(_ measurement: SentryAppStartMeasurement)
}

/// Attaches app start data to the first UIViewController transaction (default behavior).
struct AttachToTransactionStrategy: AppStartReportingStrategy {
    func report(_ measurement: SentryAppStartMeasurement) {
        SentrySDKInternal.setAppStartMeasurement(measurement)
    }
}

/// Sends a standalone app start transaction by passing the measurement directly via the tracer
/// configuration. The existing tracer pipeline then handles span building, measurements, context,
/// debug images, and profiling.
struct StandaloneTransactionStrategy: AppStartReportingStrategy {
    func report(_ measurement: SentryAppStartMeasurement) {
        guard SentrySDK.isEnabled else {
            SentrySDKLog.warning("SDK is not enabled, dropping standalone app start transaction")
            return
        }

        let operation = SentrySpanOperationAppStart
        let name = "App Start"

        let appStartTraceId = SentryAppStartMeasurementProvider.appStartTraceId()
        let context: TransactionContext
        if let traceId = appStartTraceId {
            context = TransactionContext(
                name: name,
                rawNameSource: SentryTransactionNameSource.component.rawValue,
                operation: operation,
                origin: SentryTraceOriginAutoAppStart,
                trace: traceId
            )
        } else {
            context = TransactionContext(
                name: name,
                rawNameSource: SentryTransactionNameSource.component.rawValue,
                operation: operation,
                origin: SentryTraceOriginAutoAppStart
            )
        }

        let configuration = SentryTracerConfiguration(block: { config in
            config.appStartMeasurement = measurement
        })

        let hub = SentrySDKInternal.currentHub()
        let tracer = hub.startTransaction(
            with: context,
            bindToScope: false,
            customSamplingContext: [:],
            configuration: configuration
        )
        if let screen = SentryAppStartMeasurementProvider.consumeAppStartScreen() {
            tracer.setData(value: screen, key: "app.vitals.start.screen")
        }
        tracer.setData(value: "launch", key: SentrySpanDataKeyAppVitalsStartReason)

        tracer.finish()
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
