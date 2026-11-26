internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Builds the app start spans a tracer adds to its transaction.
///
/// SentryTracer belongs to _SentryPrivate and cannot appear in the exported Swift interface, so
/// the Objective-C entry points take `AnyObject`. Internal Swift callers use the typed overloads.
@_spi(Private) @objc public final class SentryBuildAppStartSpans: NSObject {

    private struct Phase {
        let operationSuffix: String
        let description: String
        let startTimestamp: Date
        let timestamp: Date
    }

    /// Builds app start spans for a UIViewController transaction. An intermediate grouping span
    /// ("Cold Start" / "Warm Start") is inserted as parent for the phase spans:
    ///
    /// ```
    /// UIViewController (op: ui.load)            ← tracer
    ///   └─ Cold Start (op: app.start.cold)      ← grouping span
    ///        ├─ Pre Runtime Init
    ///        ├─ Runtime Init to Pre Main Initializers
    ///        ├─ UIKit Init
    ///        ├─ Application Init
    ///        └─ Initial Frame Render
    /// ```
    @objc(buildAppStartSpansForTracer:appStartMeasurement:)
    public static func buildAppStartSpans(forTracer tracer: AnyObject, appStartMeasurement: SentryAppStartMeasurement?) -> [any Span] {
        guard let tracer = tracer as? SentryTracer else { return [] }
        return buildAppStartSpans(tracer: tracer, appStartMeasurement: appStartMeasurement)
    }

    /// Builds app start spans for a standalone app start transaction. Phase spans are parented
    /// directly to the tracer (no intermediate grouping span), and there is no frame render span
    /// because standalone app starts end at didFinishLaunching:
    ///
    /// ```
    /// App Start (op: app.start)                 ← tracer
    ///   ├─ Pre Runtime Init
    ///   ├─ Runtime Init to Pre Main Initializers
    ///   ├─ UIKit Init
    ///   └─ Application Init
    /// ```
    @objc(buildStandaloneAppStartSpansForTracer:appStartMeasurement:)
    public static func buildStandaloneAppStartSpans(forTracer tracer: AnyObject, appStartMeasurement: SentryAppStartMeasurement?) -> [any Span] {
        guard let tracer = tracer as? SentryTracer else { return [] }
        return buildStandaloneAppStartSpans(tracer: tracer, appStartMeasurement: appStartMeasurement)
    }

    static func buildAppStartSpans(tracer: SentryTracer, appStartMeasurement: SentryAppStartMeasurement?) -> [any Span] {
        guard let appStartMeasurement else {
            return []
        }

        let operation: String
        let description: String
        switch appStartMeasurement.type {
        case .cold:
            operation = SentrySpanOperationAppStartCold
            description = "Cold Start"
        case .warm:
            operation = SentrySpanOperationAppStartWarm
            description = "Warm Start"
        default:
            SentrySDKLog.error("Unknown app start type, can't build app start spans")
            return []
        }

        let appStartEndTimestamp = appStartMeasurement.appStartTimestamp.addingTimeInterval(appStartMeasurement.duration)

        let appStartSpan = buildSpan(
            tracer: tracer,
            parentId: tracer.spanId,
            operation: operation,
            description: description,
            startTimestamp: appStartMeasurement.appStartTimestamp,
            timestamp: appStartEndTimestamp
        )

        var appStartSpans = [appStartSpan]
        for phase in phases(of: appStartMeasurement) {
            appStartSpans.append(buildSpan(
                tracer: tracer,
                parentId: appStartSpan.spanId,
                operation: operation,
                description: phase.description,
                startTimestamp: phase.startTimestamp,
                timestamp: phase.timestamp
            ))
        }
        appStartSpans.append(buildSpan(
            tracer: tracer,
            parentId: appStartSpan.spanId,
            operation: operation,
            description: "Initial Frame Render",
            startTimestamp: appStartMeasurement.didFinishLaunchingTimestamp,
            timestamp: appStartEndTimestamp
        ))

        return appStartSpans
    }

    static func buildStandaloneAppStartSpans(tracer: SentryTracer, appStartMeasurement: SentryAppStartMeasurement?) -> [any Span] {
        guard let appStartMeasurement else {
            return []
        }

        // The unified app.start operation doesn't encode the start type, so the phase spans
        // carry it as span data instead.
        let startType: String?
        switch appStartMeasurement.type {
        case .cold: startType = "cold"
        case .warm: startType = "warm"
        default: startType = nil
        }

        // Standalone app starts end at didFinishLaunching, so there is no frame render span.
        return phases(of: appStartMeasurement).map { phase in
            let span = buildSpan(
                tracer: tracer,
                parentId: tracer.spanId,
                operation: "\(SentrySpanOperationAppStart).\(phase.operationSuffix)",
                description: phase.description,
                startTimestamp: phase.startTimestamp,
                timestamp: phase.timestamp
            )
            if let startType {
                span.setData(value: startType, key: SentrySpanDataKeyAppVitalsStartType)
            }
            return span
        }
    }

    private static func phases(of appStartMeasurement: SentryAppStartMeasurement) -> [Phase] {
        var phases = [Phase]()

        if !appStartMeasurement.isPreWarmed {
            phases.append(Phase(
                operationSuffix: "pre_runtime_init",
                description: "Pre Runtime Init",
                startTimestamp: appStartMeasurement.appStartTimestamp,
                timestamp: appStartMeasurement.runtimeInitTimestamp
            ))
            phases.append(Phase(
                operationSuffix: "runtime_init",
                description: "Runtime Init to Pre Main Initializers",
                startTimestamp: appStartMeasurement.runtimeInitTimestamp,
                timestamp: appStartMeasurement.moduleInitializationTimestamp
            ))
        }

        phases.append(Phase(
            operationSuffix: "uikit_init",
            description: "UIKit Init",
            startTimestamp: appStartMeasurement.moduleInitializationTimestamp,
            timestamp: appStartMeasurement.sdkStartTimestamp
        ))
        phases.append(Phase(
            operationSuffix: "application_init",
            description: "Application Init",
            startTimestamp: appStartMeasurement.sdkStartTimestamp,
            timestamp: appStartMeasurement.didFinishLaunchingTimestamp
        ))

        return phases
    }

    private static func buildSpan(
        tracer: SentryTracer,
        parentId: SpanId,
        operation: String,
        description: String,
        startTimestamp: Date,
        timestamp: Date
    ) -> any Span {
        let context = SpanContext(
            trace: tracer.traceId,
            spanId: SpanId(),
            parentId: parentId,
            operation: operation,
            spanDescription: description,
            sampled: tracer.sampled
        )
        context.origin = SentryTraceOriginAutoAppStart

        // Pass nil for the framesTracker because app start spans are created during launch,
        // before the frames tracker is available.
        let span = SentrySpanInternal(tracer: tracer, context: context, framesTracker: nil)
        span.startTimestamp = startTimestamp
        span.timestamp = timestamp
        return span
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
