import Foundation

extension SentryHeldFatalReport {
    /// A JSON value of any shape, which makes the dictionaries the SDK's types serialize to `Codable`.
    ///
    /// `Event` and `SentrySession` serialize to `[String: Any]` and aren't `Encodable`, so the held
    /// report encodes this instead.
    ///
    /// Only a bridge for the held report: once `Event` and `SentrySession` are `Codable`, the report
    /// synthesizes its conformance and this type goes away. The file keeps its format, because this
    /// writes the same nested JSON objects those types will.
    ///
    /// Unlike ``ArbitraryData``, which only decodes, it keeps every value the way JSON has it. It
    /// doesn't turn a string that looks like a date into a `Date`, so the dictionary it gives back is
    /// the one that was stored, which the `init(jsonObject:)` of the SDK's types can read.
    enum JSONValue: Codable, Equatable {
        case null
        case bool(Bool)
        case int(Int64)
        /// An integer above `Int64.max`, such as a memory address.
        case uint(UInt64)
        case double(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])

        /// - Parameter jsonObject: A value as `JSONSerialization` takes it: a string, number, `NSNull`,
        ///   array or dictionary with string keys.
        /// - Returns: `nil` when the value, or one inside it, is none of these or a number JSON can't
        ///   represent.
        init?(jsonObject: Any) {
            switch jsonObject {
            case let string as String:
                self = .string(string)
            case let number as NSNumber:
                guard let value = Self.number(number) else {
                    return nil
                }
                self = value
            case is NSNull:
                self = .null
            case let dictionary as [String: Any]:
                guard let object = Self.object(dictionary) else {
                    return nil
                }
                self = .object(object)
            case let elements as [Any]:
                guard let array = Self.array(elements) else {
                    return nil
                }
                self = .array(array)
            default:
                return nil
            }
        }

        /// The value as `JSONSerialization` returns it.
        var jsonObject: Any {
            switch self {
            case .null:
                return NSNull()
            case let .bool(value):
                return NSNumber(value: value)
            case let .int(value):
                return NSNumber(value: value)
            case let .uint(value):
                return NSNumber(value: value)
            case let .double(value):
                return NSNumber(value: value)
            case let .string(value):
                return value
            case let .array(elements):
                return elements.map { $0.jsonObject }
            case let .object(object):
                return object.mapValues { $0.jsonObject }
            }
        }

        private static func object(_ dictionary: [String: Any]) -> [String: JSONValue]? {
            var object = [String: JSONValue](minimumCapacity: dictionary.count)
            for (key, element) in dictionary {
                guard let value = JSONValue(jsonObject: element) else {
                    return nil
                }
                object[key] = value
            }
            return object
        }

        private static func array(_ elements: [Any]) -> [JSONValue]? {
            var array = [JSONValue]()
            array.reserveCapacity(elements.count)
            for element in elements {
                guard let value = JSONValue(jsonObject: element) else {
                    return nil
                }
                array.append(value)
            }
            return array
        }

        private static func number(_ number: NSNumber) -> JSONValue? {
            // A Boolean is an NSNumber too, and only its type tells it from 0 and 1.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            if CFNumberIsFloatType(number) {
                let double = number.doubleValue
                return double.isFinite ? .double(double) : nil
            }
            if let int = Int64(exactly: number) {
                return .int(int)
            }
            return .uint(number.uint64Value)
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            // A Boolean is tried before the numbers and an integer before a double, so each value
            // keeps the type it was encoded with.
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Int64.self) {
                self = .int(value)
            } else if let value = try? container.decode(UInt64.self) {
                self = .uint(value)
            } else if let value = try? container.decode(Double.self) {
                self = .double(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .null:
                try container.encodeNil()
            case let .bool(value):
                try container.encode(value)
            case let .int(value):
                try container.encode(value)
            case let .uint(value):
                try container.encode(value)
            case let .double(value):
                try container.encode(value)
            case let .string(value):
                try container.encode(value)
            case let .array(value):
                try container.encode(value)
            case let .object(value):
                try container.encode(value)
            }
        }
    }
}
