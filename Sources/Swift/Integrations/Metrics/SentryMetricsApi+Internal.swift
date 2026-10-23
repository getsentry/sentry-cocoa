import Foundation

// These overloads let SDK integrations record a metric for a moment in the past, such as a
// MetricKit payload delivered up to a day after its reporting interval. They are internal on
// purpose: `SentrySDK.metrics` is typed as the public `SentryMetricsApiProtocol`, which doesn't
// expose them.
//
// The SDK doesn't limit how old the timestamp may be. Relay rejects trace metrics older than
// the organization's trace metric retention and corrects timestamps for clock drift, so
// ingestion owns that decision.
extension SentryMetricsApi {
    func count(key: String, value: UInt, timestamp: Date, attributes: [String: SentryAttributeValue] = [:]) {
        captureMetric(name: key, value: .counter(value), unit: nil, timestamp: timestamp, attributes: attributes)
    }

    func distribution(key: String, value: Double, unit: SentryUnit? = nil, timestamp: Date, attributes: [String: SentryAttributeValue] = [:]) {
        captureMetric(name: key, value: .distribution(value), unit: unit, timestamp: timestamp, attributes: attributes)
    }

    func gauge(key: String, value: Double, unit: SentryUnit? = nil, timestamp: Date, attributes: [String: SentryAttributeValue] = [:]) {
        captureMetric(name: key, value: .gauge(value), unit: unit, timestamp: timestamp, attributes: attributes)
    }
}
