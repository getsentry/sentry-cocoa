import Foundation

/// The metrics API that SDK integrations use to record a metric a previous process recorded, such
/// as a MetricKit payload delivered up to a day after its reporting interval.
///
/// It is internal on purpose: `SentrySDK.metrics` is typed as the public
/// `SentryMetricsApiProtocol`, which only exposes the timestamp through ``SentryMetricOptions``.
///
/// Such a metric only gets the scope attributes that can't change between app runs, such as the
/// environment, the OS name and the device model. The user, the replay, the custom scope
/// attributes and the running OS version are left out, like the client leaves out the scope for
/// events from a previous process. The `attributes` take precedence over the scope, so they carry
/// the `sentry.release` and `os.version` the metric was recorded with. The metric gets the given
/// `traceId` instead of the running trace.
///
/// The SDK doesn't limit how old the timestamp may be. Relay rejects trace metrics older than
/// the organization's trace metric retention and corrects timestamps for clock drift, so
/// ingestion owns that decision.
protocol SentryInternalMetricsApi {
    func count(
        key: String,
        value: UInt,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue]
    )

    func distribution(
        key: String,
        value: Double,
        unit: SentryUnit?,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue]
    )

    func gauge(
        key: String,
        value: Double,
        unit: SentryUnit?,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue]
    )
}

extension SentryMetricsApi: SentryInternalMetricsApi {
    func count(
        key: String,
        value: UInt,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .counter(value), unit: nil, options: SentryMetricOptions(attributes: attributes, timestamp: timestamp), previousProcessTraceId: traceId)
    }

    func distribution(
        key: String,
        value: Double,
        unit: SentryUnit? = nil,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .distribution(value), unit: unit, options: SentryMetricOptions(unit: unit, attributes: attributes, timestamp: timestamp), previousProcessTraceId: traceId)
    }

    func gauge(
        key: String,
        value: Double,
        unit: SentryUnit? = nil,
        timestamp: Date,
        traceId: SentryId,
        attributes: [String: SentryAttributeValue] = [:]
    ) {
        captureMetric(name: key, value: .gauge(value), unit: unit, options: SentryMetricOptions(unit: unit, attributes: attributes, timestamp: timestamp), previousProcessTraceId: traceId)
    }
}
