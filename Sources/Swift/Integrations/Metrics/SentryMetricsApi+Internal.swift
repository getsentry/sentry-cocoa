import Foundation

/// The metrics API that SDK integrations use to record a metric for a moment in the past, such as
/// a MetricKit payload delivered up to a day after its reporting interval.
///
/// It is internal on purpose: `SentrySDK.metrics` is typed as the public
/// `SentryMetricsApiProtocol`, which only exposes the timestamp through ``SentryMetricOptions``
/// and doesn't expose `overridingAttributes`.
///
/// The SDK doesn't limit how old the timestamp may be. Relay rejects trace metrics older than
/// the organization's trace metric retention and corrects timestamps for clock drift, so
/// ingestion owns that decision.
///
/// `overridingAttributes` replace the attributes scope enrichment sets, such as `sentry.release`
/// or `os.version`, when the metric describes an app or OS version other than the running one.
protocol SentryInternalMetricsApi {
    func count(
        key: String,
        value: UInt,
        timestamp: Date,
        attributes: [String: SentryAttributeValue],
        overridingAttributes: [String: SentryAttributeValue]
    )

    func distribution(
        key: String,
        value: Double,
        unit: SentryUnit?,
        timestamp: Date,
        attributes: [String: SentryAttributeValue],
        overridingAttributes: [String: SentryAttributeValue]
    )

    func gauge(
        key: String,
        value: Double,
        unit: SentryUnit?,
        timestamp: Date,
        attributes: [String: SentryAttributeValue],
        overridingAttributes: [String: SentryAttributeValue]
    )
}

extension SentryMetricsApi: SentryInternalMetricsApi {
    func count(
        key: String,
        value: UInt,
        timestamp: Date,
        attributes: [String: SentryAttributeValue] = [:],
        overridingAttributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .counter(value), unit: nil, options: SentryMetricOptions(attributes: attributes, timestamp: timestamp), overridingAttributes: overridingAttributes)
    }

    func distribution(
        key: String,
        value: Double,
        unit: SentryUnit? = nil,
        timestamp: Date,
        attributes: [String: SentryAttributeValue] = [:],
        overridingAttributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .distribution(value), unit: unit, options: SentryMetricOptions(unit: unit, attributes: attributes, timestamp: timestamp), overridingAttributes: overridingAttributes)
    }

    func gauge(
        key: String,
        value: Double,
        unit: SentryUnit? = nil,
        timestamp: Date,
        attributes: [String: SentryAttributeValue] = [:],
        overridingAttributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .gauge(value), unit: unit, options: SentryMetricOptions(unit: unit, attributes: attributes, timestamp: timestamp), overridingAttributes: overridingAttributes)
    }
}
