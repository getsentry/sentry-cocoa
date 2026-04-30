import Foundation
import SentryObjCTypes

#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif

// MARK: - SentryObjCAttributeContent

extension SentryObjCAttributeContent {
    func toSwift() -> SentryAttributeContent {
        switch type {
        case .string:       return .string(stringValue ?? "")
        case .boolean:      return .boolean(booleanValue)
        case .integer:      return .integer(integerValue)
        case .double:       return .double(doubleValue)
        case .stringArray:  return .stringArray(stringArrayValue ?? [])
        case .booleanArray: return .booleanArray((booleanArrayValue ?? []).map(\.boolValue))
        case .integerArray: return .integerArray((integerArrayValue ?? []).map(\.intValue))
        case .doubleArray:  return .doubleArray((doubleArrayValue ?? []).map(\.doubleValue))
        @unknown default:   return .string("")
        }
    }
}

extension SentryAttributeContent {
    func toObjC() -> SentryObjCAttributeContent {
        switch self {
        case .string(let v):       return .string(withValue: v)
        case .boolean(let v):      return .boolean(withValue: v)
        case .integer(let v):      return .integer(withValue: v)
        case .double(let v):       return .double(withValue: v)
        case .stringArray(let v):  return .stringArray(withValue: v)
        case .booleanArray(let v): return .booleanArray(withValue: v.map { NSNumber(value: $0) })
        case .integerArray(let v): return .integerArray(withValue: v.map { NSNumber(value: $0) })
        case .doubleArray(let v):  return .doubleArray(withValue: v.map { NSNumber(value: $0) })
        @unknown default:          return .string(withValue: "")
        }
    }
}

// MARK: - SentryObjCMetricValue

extension SentryMetricValue {
    func toObjC() -> SentryObjCMetricValue {
        switch self {
        case .counter(let v):      return .counter(withValue: UInt64(v))
        case .gauge(let v):        return .gauge(withValue: v)
        case .distribution(let v): return .distribution(withValue: v)
        @unknown default:          return .counter(withValue: 0)
        }
    }
}

extension SentryObjCMetricValue {
    func toSwift() -> SentryMetricValue {
        switch type {
        case .counter:      return .counter(UInt(counterValue))
        case .gauge:        return .gauge(gaugeValue)
        case .distribution: return .distribution(distributionValue)
        @unknown default:   return .counter(UInt(counterValue))
        }
    }
}

// MARK: - SentryObjCMetric

extension SentryMetric {
    func toObjC() -> SentryObjCMetric {
        return SentryObjCMetric(
            timestamp: timestamp,
            name: name,
            trace: traceId,
            spanId: spanId,
            value: value.toObjC(),
            unit: unit?.rawValue,
            attributes: attributes.mapValues { $0.toObjC() }
        )
    }
}

extension SentryObjCMetric {
    func toSwift() -> SentryMetric {
        return SentryMetric(
            timestamp: timestamp,
            traceId: traceId,
            name: name,
            value: value.toSwift(),
            unit: unit.flatMap { SentryUnit(rawValue: $0) },
            attributes: attributes.mapValues { $0.toSwift() }
        )
    }
}
