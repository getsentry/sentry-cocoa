// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// The Telemetry processor is sitting between the client and transport to efficiently deliver telemetry to Sentry (as of 2026-02-04).
/// Currently used for logs and metrics only; planned to cover all telemetry with buffering, rate limiting, client reports, and priority-based sending.
/// Offline caching is still handled by the transport today, but the long-term goal is to move it here so the transport focuses on sending only.
/// This is an Objective-C compatible subset of the telemetry processor protocol.
/// Use `SentryTelemetryProcessor` instead when working in Swift, which adds support for
/// Swift-only types like `SentryMetric`.
/// See dev docs for details (work in progress): https://develop.sentry.dev/sdk/telemetry/telemetry-processor/
@objc @_spi(Private) public protocol SentryObjCTelemetryProcessor {
    @objc(addLog:)
    func add(log: SentryLog)
    /// Forwards buffered telemetry data to the transport for sending.
    func forwardTelemetryData() -> TimeInterval
}
/// This extends `SentryObjCTelemetryProcessor` with Swift-only types like `SentryMetric` that cannot
/// be represented in Objective-C.
protocol SentryTelemetryProcessor: SentryObjCTelemetryProcessor {
    func add(metric: SentryMetric)
}

class SentryDefaultTelemetryProcessor: SentryTelemetryProcessor {

    private let logBuffer: any TelemetryBuffer<SentryLog>
    private let metricsBuffer: any TelemetryBuffer<SentryMetric>

    init(logBuffer: any TelemetryBuffer<SentryLog>, metricsBuffer: any TelemetryBuffer<SentryMetric>) {
        self.logBuffer = logBuffer
        self.metricsBuffer = metricsBuffer
    }

    func add(log: SentryLog) {
        self.logBuffer.add(log)
    }

    func add(metric: SentryMetric) {
        self.metricsBuffer.add(metric)
    }

    func forwardTelemetryData() -> TimeInterval {
        let logDuration = self.logBuffer.capture()
        let metricsDuration = self.metricsBuffer.capture()
        return logDuration + metricsDuration
    }
}

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
typealias SentryTelemetryProcessorFactoryDependencies = DateProviderProvider & NotificationCenterProvider
#else
typealias SentryTelemetryProcessorFactoryDependencies = DateProviderProvider
#endif

/// Factory for creating telemetry processors.
///
/// Unlike integrations (e.g., `SentryMetricsIntegration`), this factory cannot yet use the full dependency injection pattern
/// because the `SentryTelemetryProcessorTransport` is created in `SentryClient` (Objective-C) and must be passed in explicitly.
///
/// **Current approach:**
/// - Public method: `getProcessor(transport:dependencies:)` - called from Objective-C with concrete `SentryDependencyContainer`
/// - Internal method: `getProcessorInternal(transport:dependencies:)` - uses protocol-constrained generics for testability
///
/// **Future migration path:**
/// Once the transport is resolved via DI, we can refactor to match the integration pattern:
/// ```swift
/// init?(transport: SentryTelemetryProcessorTransport, dependencies: Dependencies)
/// ```
/// The internal method is already structured to make this transition straightforward.
@objc
@objcMembers
@_spi(Private) public class SentryTelemetryProcessorFactory: NSObject {
    public static func getProcessor(transport: SentryTelemetryProcessorTransport, dependencies: SentryDependencyContainer) -> SentryObjCTelemetryProcessor {
        return getProcessorInternal(transport: transport, dependencies: dependencies)
    }

    private static func getProcessorInternal<Dependencies: SentryTelemetryProcessorFactoryDependencies>(
        transport: SentryTelemetryProcessorTransport,
        dependencies: Dependencies
    ) -> SentryObjCTelemetryProcessor {
        let scheduler = DefaultTelemetryScheduler(transport: transport)

        // Separate instance per buffer because each trigger only supports one delegate.
        #if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
        let logsItemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers(
            notificationCenter: dependencies.notificationCenterWrapper
        )
        #else
        let logsItemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers()
        #endif

        // Uses DEFAULT priority (not LOW) because capture() is called synchronously during
        // app lifecycle events (willResignActive, willTerminate) and needs to complete quickly.
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.log-batcher")

        let logBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryLog>, SentryLog>(
            config: .init(
                flushTimeout: 5,
                maxItemCount: 100, // Maximum 100 logs per batch; keep lower than Replay hard limit of 1000
                maxBufferSizeBytes: 1_024 * 1_024, // 1MB buffer size
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .log)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dependencies.dateProvider,
            dispatchQueue: dispatchQueue,
            itemForwardingTriggers: logsItemForwardingTriggers
        )

        // Separate instance per buffer because each trigger only supports one delegate.
        #if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
        let metricsItemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers(
            notificationCenter: dependencies.notificationCenterWrapper
        )
        #else
        let metricsItemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers()
        #endif

        let metricsDispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.metric-batcher")

        let metricsBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryMetric>, SentryMetric>(
            config: .init(
                flushTimeout: 5,
                maxItemCount: 100, // Maximum 100 metrics per batch
                maxBufferSizeBytes: 1_024 * 1_024, // 1MB buffer size
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .metric)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dependencies.dateProvider,
            dispatchQueue: metricsDispatchQueue,
            itemForwardingTriggers: metricsItemForwardingTriggers
        )

        return SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
    }
}

// swiftlint:enable missing_docs
