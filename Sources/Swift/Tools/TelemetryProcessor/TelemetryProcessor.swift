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

/// Factory (not the dependency container) used because the transport + its adapter are created in `SentryClient`, not resolved via DI (as of 2026-02-04).
/// This allows passing the client-owned transport into the telemetry processor while keeping Swift internals hidden from ObjC.
@objc
@objcMembers
@_spi(Private) public class SentryTelemetryProcessorFactory: NSObject {
    public static func getProcessor(transport: SentryTelemetryProcessorTransport, notificationCenter: SentryNSNotificationCenterWrapper) -> SentryTelemetryProcessor {
        let scheduler = DefaultTelemetryScheduler(transport: transport)
        let logBuffer = SentryLogBuffer(dateProvider: SentryDefaultCurrentDateProvider(), scheduler: scheduler, notificationCenter: notificationCenter)
        return SentryDefaultTelemetryProcessor(logBuffer: logBuffer)
    }
}

// swiftlint:enable missing_docs
