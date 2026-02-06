// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// The Telemetry processor is sitting between the client and transport to efficiently deliver telemetry to Sentry (as of 2026-02-04).
/// Currently used for logs only; planned to cover all telemetry (e.g. metrics) with buffering, rate limiting, client reports, and priority-based sending.
/// Offline caching is still handled by the transport today, but the long-term goal is to move it here so the transport focuses on sending only.
/// See dev docs for details (work in progress): https://develop.sentry.dev/sdk/telemetry/telemetry-processor/
@objc @_spi(Private) public protocol SentryTelemetryProcessor {
    @objc(addLog:)
    func add(log: SentryLog)
    /// Forwards buffered telemetry data to the transport for sending.
    /// Temporary name; will be renamed to `flush()` once flushing logic moves from SentryMetricsIntegration.
    func forwardTelemetryData() -> TimeInterval
}

class SentryDefaultTelemetryProcessor: SentryTelemetryProcessor {

    private let logBuffer: SentryLogBuffer

    init(logBuffer: SentryLogBuffer) {
        self.logBuffer = logBuffer
    }

    func add(log: SentryLog) {
        self.logBuffer.addLog(log)
    }

    func forwardTelemetryData() -> TimeInterval {
        return self.logBuffer.captureLogs()
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
    public static func getProcessor(transport: SentryTelemetryProcessorTransport, dependencies: SentryDependencyContainer) -> SentryTelemetryProcessor {
        return getProcessorInternal(transport: transport, dependencies: dependencies)
    }

    private static func getProcessorInternal<Dependencies: SentryTelemetryProcessorFactoryDependencies>(
        transport: SentryTelemetryProcessorTransport,
        dependencies: Dependencies
    ) -> SentryTelemetryProcessor {
        let scheduler = DefaultTelemetryScheduler(transport: transport)

        #if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK
        let itemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers(
            notificationCenter: dependencies.notificationCenterWrapper
        )
        #else
        let itemForwardingTriggers = DefaultTelemetryBufferDataForwardingTriggers()
        #endif

        let logBuffer = SentryLogBuffer(
            dateProvider: dependencies.dateProvider,
            scheduler: scheduler,
            itemForwardingTriggers: itemForwardingTriggers
        )

        return SentryDefaultTelemetryProcessor(logBuffer: logBuffer)
    }
}

// swiftlint:enable missing_docs
