// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

// See Box.swift for why resilient value types are boxed in ObjC wrapper classes.
@objc(SentryObjCMetric) public final class SentryObjCMetric: NSObject {
    private var wrapped: Box<SentryMetric>

    internal init(_ wrapped: SentryMetric) {
        self.wrapped = Box(wrapped)
    }

    internal var metric: SentryMetric {
        get { wrapped.value }
        set { wrapped = Box(newValue) }
    }

    @objc public init(
        timestamp: Date,
        traceId: SentryObjCId,
        name: String,
        value: SentryObjCMetricValue,
        unit: SentryObjCUnit?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        self.wrapped = Box(SentryMetric(
            timestamp: timestamp,
            traceId: traceId.wrapped,
            name: name,
            value: value.toMetricValue(),
            unit: unit?.toSentryUnit(),
            attributes: attributes.mapValues { $0.toAttributeContent() }
        ))
    }

    @objc public var timestamp: Date {
        get { metric.timestamp }
        set { metric.timestamp = newValue }
    }

    @objc public var name: String {
        get { metric.name }
        set { metric.name = newValue }
    }

    @objc public var traceId: SentryObjCId {
        get { SentryObjCId(metric.traceId) }
        set { metric.traceId = newValue.wrapped }
    }

    @objc public var spanId: SentryObjCSpanId? {
        get { metric.spanId.map { SentryObjCSpanId($0) } }
        set { metric.spanId = newValue?.wrapped }
    }

    @objc public var value: SentryObjCMetricValue {
        get { SentryObjCMetricValue(metric.value) }
        set { metric.value = newValue.toMetricValue() }
    }

    @objc public var unit: SentryObjCUnit? {
        get { metric.unit.map { SentryObjCUnit($0) } }
        set { metric.unit = newValue?.toSentryUnit() }
    }

    @objc public var attributes: [String: SentryObjCAttributeContent] {
        get { metric.attributes.mapValues { SentryObjCAttributeContent($0) } }
        set { metric.attributes = newValue.mapValues { $0.toAttributeContent() } }
    }
}

// swiftlint:enable missing_docs
