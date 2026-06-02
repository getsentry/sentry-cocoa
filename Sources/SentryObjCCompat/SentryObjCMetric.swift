// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCMetric) public final class SentryObjCMetric: NSObject {
    internal var wrapped: SentryMetric

    internal init(_ wrapped: SentryMetric) {
        self.wrapped = wrapped
    }

    @objc public init(
        timestamp: Date,
        traceId: SentryObjCId,
        name: String,
        value: SentryObjCMetricValue,
        unit: SentryObjCUnit?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        self.wrapped = SentryMetric(
            timestamp: timestamp,
            traceId: traceId.wrapped,
            name: name,
            value: value.toMetricValue(),
            unit: unit?.toSentryUnit(),
            attributes: attributes.mapValues { $0.toAttributeContent() }
        )
    }

    @objc public var timestamp: Date {
        get { wrapped.timestamp }
        set { wrapped.timestamp = newValue }
    }

    @objc public var name: String {
        get { wrapped.name }
        set { wrapped.name = newValue }
    }

    @objc public var traceId: SentryObjCId {
        get { SentryObjCId(wrapped.traceId) }
        set { wrapped.traceId = newValue.wrapped }
    }

    @objc public var spanId: SentryObjCSpanId? {
        get { wrapped.spanId.map { SentryObjCSpanId($0) } }
        set { wrapped.spanId = newValue?.wrapped }
    }

    @objc public var value: SentryObjCMetricValue {
        get { SentryObjCMetricValue(wrapped.value) }
        set { wrapped.value = newValue.toMetricValue() }
    }

    @objc public var unit: SentryObjCUnit? {
        get { wrapped.unit.map { SentryObjCUnit($0) } }
        set { wrapped.unit = newValue?.toSentryUnit() }
    }

    @objc public var attributes: [String: SentryObjCAttributeContent] {
        get { wrapped.attributes.mapValues { SentryObjCAttributeContent($0) } }
        set { wrapped.attributes = newValue.mapValues { $0.toAttributeContent() } }
    }
}

// swiftlint:enable missing_docs
