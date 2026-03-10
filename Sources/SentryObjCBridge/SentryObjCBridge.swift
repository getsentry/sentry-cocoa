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
@objc public final class SentryObjCBridge: NSObject {

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

    // MARK: - Private Helpers

    /// Convert ObjC attributes dictionary to Swift [String: SentryAttributeValue]
    ///
    /// This method extracts attribute values from SentryObjCAttributeContent instances
    /// and converts them to their Swift SentryAttributeContent equivalents.
    ///
    /// Uses KVC to extract values from ObjC objects since we can't directly import
    /// SentryObjC types here (would create circular dependency).
    private static func convertObjCAttributesToSwift(_ objcAttributes: [String: Any]) -> [String: SentryAttributeValue] {
        var swiftAttributes: [String: SentryAttributeValue] = [:]

        for (key, value) in objcAttributes {
            // Extract values from SentryObjCAttributeContent instances using KVC
            guard let attributeContent = value as? NSObject else { continue }

            // Get the type property via KVC
            guard let typeValue = attributeContent.value(forKey: "type") as? Int else { continue }

            // Convert based on type (matches SentryObjCAttributeContentType enum)
            let swiftValue: SentryAttributeContent
            switch typeValue {
            case 0: // String
                if let stringValue = attributeContent.value(forKey: "stringValue") as? String {
                    swiftValue = .string(stringValue)
                } else {
                    continue
                }
            case 1: // Boolean
                if let boolValue = attributeContent.value(forKey: "booleanValue") as? Bool {
                    swiftValue = .boolean(boolValue)
                } else {
                    continue
                }
            case 2: // Integer
                if let intValue = attributeContent.value(forKey: "integerValue") as? Int {
                    swiftValue = .integer(intValue)
                } else {
                    continue
                }
            case 3: // Double
                if let doubleValue = attributeContent.value(forKey: "doubleValue") as? Double {
                    swiftValue = .double(doubleValue)
                } else {
                    continue
                }
            case 4: // StringArray
                if let stringArray = attributeContent.value(forKey: "stringArrayValue") as? [String] {
                    swiftValue = .stringArray(stringArray)
                } else {
                    continue
                }
            case 5: // BooleanArray
                if let boolArray = attributeContent.value(forKey: "booleanArrayValue") as? [NSNumber] {
                    swiftValue = .booleanArray(boolArray.map { $0.boolValue })
                } else {
                    continue
                }
            case 6: // IntegerArray
                if let intArray = attributeContent.value(forKey: "integerArrayValue") as? [NSNumber] {
                    swiftValue = .integerArray(intArray.map { $0.intValue })
                } else {
                    continue
                }
            case 7: // DoubleArray
                if let doubleArray = attributeContent.value(forKey: "doubleArrayValue") as? [NSNumber] {
                    swiftValue = .doubleArray(doubleArray.map { $0.doubleValue })
                } else {
                    continue
                }
            default:
                continue
            }

            swiftAttributes[key] = swiftValue as? any SentryAttributeValue
        }

        return swiftAttributes
    }
}
