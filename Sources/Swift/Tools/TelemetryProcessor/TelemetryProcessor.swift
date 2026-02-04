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

protocol TelemetryScheduler {
    func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType, )
}

enum TelemetrySchedulerItemType {
    case log
}

struct DefaultTelemetryScheduler: TelemetryScheduler {

    struct EnvelopeInfo {
        let itemType: String
        let contentType: String
    }

    private let transport: SentryTelemetryProcessorTransport

    init(transport: SentryTelemetryProcessorTransport) {
        self.transport = transport
    }

    public func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType) {

        let envelopeInfo = getEnvelopeInfo(telemetryType: telemetryType)

        let envelopeItem = SentryEnvelopeItem(type: envelopeInfo.itemType, data: data, contentType: envelopeInfo.contentType, itemCount: NSNumber(value: count))

        let envelope = SentryEnvelope(header: SentryEnvelopeHeader.empty(), items: [envelopeItem])

        transport.sendEnvelope(envelope: envelope)
    }

    private func getEnvelopeInfo(telemetryType: TelemetrySchedulerItemType) -> EnvelopeInfo {
        switch telemetryType {
            case .log: return EnvelopeInfo(itemType: SentryEnvelopeItemTypes.log, contentType: "application/vnd.sentry.items.log+json")
        }
    }
}

@objc @_spi(Private) public protocol SentryTelemetryProcessorTransport {
    func sendEnvelope(envelope: SentryEnvelope)
}

// swiftlint:enable missing_docs
