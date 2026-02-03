// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public protocol SentryTelemetryProcessor {
    func add(log: SentryLog)
    func flush() -> TimeInterval
}

@objc
@objcMembers
@_spi(Private) public class SentryTelemetryProcessorFactory: NSObject {
    public static func getProcessor(transport: SentryTelemetryProcessorTransport) -> SentryTelemetryProcessor {

        let scheduler = DefaultTelemetryScheduler(transport: transport)

        let logBuffer = SentryLogBuffer(dateProvider: SentryDefaultCurrentDateProvider(), scheduler: scheduler)

        return DefaultSentryTelemetryProcessor(logBuffer: logBuffer)
    }
}

class DefaultSentryTelemetryProcessor: SentryTelemetryProcessor {

    private let logBuffer: SentryLogBuffer

    init(logBuffer: SentryLogBuffer) {
        self.logBuffer = logBuffer
    }

    func add(log: SentryLog) {
        self.logBuffer.addLog(log)
    }

    func flush() -> TimeInterval {
        return self.logBuffer.captureLogs()
    }
}

protocol LogTelemetryScheduler: AnyObject {
    func capture(logsData: Data, count: Int)
}

class DefaultTelemetryScheduler: LogTelemetryScheduler {
    private let transport: SentryTelemetryProcessorTransport

    init(transport: SentryTelemetryProcessorTransport) {
        self.transport = transport
    }

    public func capture(logsData: Data, count: Int) {
        let envelopeItem = SentryEnvelopeItem(type: SentryEnvelopeItemTypes.log, data: logsData, contentType: "application/vnd.sentry.items.log+json", itemCount: NSNumber(value: count))

        let envelope = SentryEnvelope(header: SentryEnvelopeHeader.empty(), items: [envelopeItem])

        transport.sendEnvelope(envelope: envelope)
    }

}

@objc @_spi(Private) public protocol SentryTelemetryProcessorTransport {
    func sendEnvelope(envelope: SentryEnvelope)
}

// swiftlint:enable missing_docs
