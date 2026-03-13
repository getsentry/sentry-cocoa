@_implementationOnly import _SentryPrivate
import Foundation

// Import the public Swift SDK module
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
public final class SentryObjCBridge: NSObject {

    // MARK: - Metrics API

    /// Bridge for count metrics from ObjC to Swift
    @objc public static func metricsCount(
        key: String,
        value: UInt,
        attributes: [String: Any]
    ) {
        let bridgedAttributes = convertObjCAttributesToSwift(attributes)
        SentrySDK.metrics.count(key: key, value: value, attributes: bridgedAttributes)
    }

    /// Bridge for distribution metrics from ObjC to Swift
    @objc public static func metricsDistribution(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: Any]
    ) {
        let bridgedAttributes = convertObjCAttributesToSwift(attributes)
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.distribution(key: key, value: value, unit: swiftUnit, attributes: bridgedAttributes)
    }

    /// Bridge for gauge metrics from ObjC to Swift
    @objc public static func metricsGauge(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: Any]
    ) {
        let bridgedAttributes = convertObjCAttributesToSwift(attributes)
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.gauge(key: key, value: value, unit: swiftUnit, attributes: bridgedAttributes)
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

    // MARK: - Private Helpers

    /// Convert ObjC attributes dictionary to Swift [String: SentryAttributeValue]
    ///
    /// This method extracts attribute values from SentryObjCAttributeContent instances
    /// and converts them to their Swift SentryAttributeContent equivalents.
    ///
    /// Uses KVC to extract values from ObjC objects since we can't directly import
    /// SentryObjC types here (would create circular dependency).
    ///
    /// Invalid attributes are silently skipped to maintain robustness.
    private static func convertObjCAttributesToSwift(_ objcAttributes: [String: Any]) -> [String: SentryAttributeValue] {
        objcAttributes.compactMapValues { value in
            guard let attributeContent = value as? NSObject,
                  let typeValue = attributeContent.value(forKey: "type") as? Int,
                  let swiftValue = convertAttributeContent(attributeContent, typeValue: typeValue),
                  let attributeValue = swiftValue as? any SentryAttributeValue
            else {
                return nil
            }
            return attributeValue
        }
    }

    /// Convert a single attribute content object to Swift SentryAttributeContent
    private static func convertAttributeContent(_ content: NSObject, typeValue: Int) -> SentryAttributeContent? {
        switch typeValue {
        case 0: return (content.value(forKey: "stringValue") as? String).map { .string($0) }
        case 1: return (content.value(forKey: "booleanValue") as? Bool).map { .boolean($0) }
        case 2: return (content.value(forKey: "integerValue") as? Int).map { .integer($0) }
        case 3: return (content.value(forKey: "doubleValue") as? Double).map { .double($0) }
        case 4: return (content.value(forKey: "stringArrayValue") as? [String]).map { .stringArray($0) }
        case 5: return (content.value(forKey: "booleanArrayValue") as? [NSNumber]).map { .booleanArray($0.map { $0.boolValue }) }
        case 6: return (content.value(forKey: "integerArrayValue") as? [NSNumber]).map { .integerArray($0.map { $0.intValue }) }
        case 7: return (content.value(forKey: "doubleArrayValue") as? [NSNumber]).map { .doubleArray($0.map { $0.doubleValue }) }
        default: return nil
        }
    }
}
