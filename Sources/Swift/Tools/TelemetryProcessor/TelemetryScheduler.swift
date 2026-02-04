// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

enum TelemetrySchedulerItemType {
    case log
}

/// The SentryHttpTransport currently does rate limiting, offline caching, recording and sending client reports, etc.
/// We plan on making the Transport focused on sending envelopes mostly. The TelemetryScheduler should do
/// priority based offline caching, rate limiting, etc. but for now it only builds the envelopes for logs.
/// For more info see https://develop.sentry.dev/sdk/telemetry/telemetry-processor/#telemetry-scheduler
protocol TelemetryScheduler {
    func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType)
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

// swiftlint:enable missing_docs
