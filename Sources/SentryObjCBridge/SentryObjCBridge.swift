import Foundation
import SentryObjCTypes

// Import the Sentry SDK module.
// SPM uses SentrySwift, Xcode uses Sentry.
#if SWIFT_PACKAGE
import SentrySwift
#else
import Sentry
#endif

/// Bridge class that exposes Swift SDK functionality to pure Objective-C code.
///
/// This class provides @objc methods that can be called from SentryObjC (pure ObjC, no modules)
/// and forwards them to the Swift SentrySDK implementation.
@objc(SentryObjCBridge)
public final class SentrySwiftBridge: NSObject {

    // MARK: - Metrics API

    /// Bridge for count metrics from ObjC to Swift
    @objc public static func metricsCount(
        key: String,
        value: UInt,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        SentrySDK.metrics.count(key: key, value: value, attributes: attributes.mapValues { $0.toSwift() })
    }

    /// Bridge for distribution metrics from ObjC to Swift
    @objc public static func metricsDistribution(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.distribution(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toSwift() })
    }

    /// Bridge for gauge metrics from ObjC to Swift
    @objc public static func metricsGauge(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.gauge(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toSwift() })
    }

    // MARK: - Logger API

    /// Bridge for logger access from ObjC to Swift
    @objc public static var logger: AnyObject {
        return SentrySDK.logger
    }

    // MARK: - Replay API

    #if SENTRY_TARGET_REPLAY_SUPPORTED
    /// Bridge for replay API access from ObjC to Swift
    @objc public static var replay: AnyObject {
        return SentrySDK.replay
    }
    #endif
}

// MARK: - ObjC → Swift mapping

private extension SentryObjCAttributeContent {
    /// Convert the public ObjC data carrier into the internal Swift enum.
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
