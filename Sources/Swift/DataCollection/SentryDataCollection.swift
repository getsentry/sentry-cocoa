import Foundation

/// Type used as namespace of all types related to data collection
///
/// - SeeAlso: [Data Collection Spec](https://develop.sentry.dev/sdk/foundations/client/data-collection)
public enum SentryDataCollection {}

extension SentryDataCollection {
    enum DictionaryDecoder {
        static func bool(_ dictionary: [String: Any], _ key: String) -> Bool? {
            guard let value = dictionary[key], !(value is NSNull) else {
                return nil
            }
            return (value as? NSNumber)?.boolValue
        }

        static func uint(_ dictionary: [String: Any], _ key: String) -> UInt? {
            guard let value = dictionary[key], !(value is NSNull), let number = value as? NSNumber else {
                return nil
            }
            guard number.intValue >= 0 else {
                return nil
            }
            return number.uintValue
        }

        static func dictionary(_ dictionary: [String: Any], _ key: String) -> [String: Any]? {
            guard let value = dictionary[key], !(value is NSNull) else {
                return nil
            }
            return value as? [String: Any]
        }

        static func strings(_ dictionary: [String: Any], _ key: String) -> [String]? {
            guard let value = dictionary[key], !(value is NSNull) else {
                return nil
            }
            return (value as? [Any])?.compactMap { $0 as? String }
        }

        static func isBool(_ number: NSNumber) -> Bool {
            String(cString: number.objCType) == "c" || String(cString: number.objCType) == "B"
        }
    }
}
