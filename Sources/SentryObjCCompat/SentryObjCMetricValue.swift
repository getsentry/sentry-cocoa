// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

// See Box.swift for why resilient value types are boxed in ObjC wrapper classes.
@objc(SentryObjCMetricValue) public final class SentryObjCMetricValue: NSObject {
    private let metricValue: Box<SentryMetricValue>

    internal init(_ metricValue: SentryMetricValue) {
        self.metricValue = Box(metricValue)
    }

    internal func toMetricValue() -> SentryMetricValue {
        metricValue.value
    }

    @objc public static func counter(_ value: UInt) -> SentryObjCMetricValue {
        SentryObjCMetricValue(.counter(value))
    }

    @objc public static func gauge(_ value: Double) -> SentryObjCMetricValue {
        SentryObjCMetricValue(.gauge(value))
    }

    @objc public static func distribution(_ value: Double) -> SentryObjCMetricValue {
        SentryObjCMetricValue(.distribution(value))
    }

    @objc public var isCounter: Bool {
        if case .counter = metricValue.value { return true }
        return false
    }

    @objc public var isGauge: Bool {
        if case .gauge = metricValue.value { return true }
        return false
    }

    @objc public var isDistribution: Bool {
        if case .distribution = metricValue.value { return true }
        return false
    }

    @objc public var counterValue: UInt {
        if case .counter(let v) = metricValue.value { return v }
        return 0
    }

    @objc public var gaugeValue: Double {
        if case .gauge(let v) = metricValue.value { return v }
        return 0
    }

    @objc public var distributionValue: Double {
        if case .distribution(let v) = metricValue.value { return v }
        return 0
    }
}

// swiftlint:enable missing_docs
