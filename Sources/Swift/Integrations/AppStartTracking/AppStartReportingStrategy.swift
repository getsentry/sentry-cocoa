@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

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

        let operation: String
        let name: String

        switch measurement.type {
        case .cold:
            operation = SentrySpanOperationAppStartCold
            name = "App Start Cold"
        case .warm:
            operation = SentrySpanOperationAppStartWarm
            name = "App Start Warm"
        default:
            SentrySDKLog.error("Unknown app start type, can't report standalone app start transaction")
            return
        }

        let context = TransactionContext(name: name, operation: operation)

        // Pass the measurement directly to the tracer via configuration instead of storing
        // it on the global static. This avoids race conditions where a UIViewController
        // transaction could consume the measurement first.
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
        tracer.origin = SentryTraceOriginAutoAppStart

        tracer.finish()
    }
}

/// Helper to identify standalone app start transactions from ObjC code.
@_spi(Private) @objc public class StandaloneAppStartTransactionHelper: NSObject {
    /// Returns `true` when the operation and origin match a standalone app start transaction.
    @objc public static func isStandaloneAppStartTransaction(operation: String, origin: String) -> Bool {
        return (operation == SentrySpanOperationAppStartCold
                || operation == SentrySpanOperationAppStartWarm)
            && origin == SentryTraceOriginAutoAppStart
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
