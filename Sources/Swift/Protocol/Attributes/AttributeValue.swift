/// A type-safe value that can be stored in an attribute.
///
/// This enum provides type safety for attribute values while supporting
/// literal initialization via `ExpressibleByX` protocols.
enum AttributeValue {
    case string(String)
    case boolean(Bool)
    case integer(Int)
    case double(Double)
    case array([SentryAttribute])

    /// The type identifier for this attribute value ("string", "boolean", "integer", "double", "string[]", "boolean[]", "integer[]", "double[]")
    var type: String {
        switch self {
        case .string:
            return "string"
        case .boolean:
            return "boolean"
        case .integer:
            return "integer"
        case .double:
            return "double"
        case .array:
            return "array[]"
        }
    }

    /// Returns the underlying value as `Any` for backward compatibility
    var anyValue: Any {
        switch self {
        case .string(let value):
            return value
        case .boolean(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .array(let value):
            return value
        }
    }

    /// Creates an `AttributeValue` from any value, converting unsupported types to strings
    init(fromAny value: Any) {
        switch value {
        case let stringValue as String:
            self = .string(stringValue)
        case let boolValue as Bool:
            self = .boolean(boolValue)
        case let intValue as Int:
            self = .integer(intValue)
        case let doubleValue as Double:
            self = .double(doubleValue)
        case let floatValue as Float:
            self = .double(Double(floatValue))
        case let arrayValue as [SentryAttribute]:
            self = .array(arrayValue)
        default:
            // For any other type, convert to string representation
            self = .string(String(describing: value))
        }
    }
}

extension AttributeValue: Encodable {
    private enum CodingKeys: String, CodingKey {
        case attributeType
        case attributeValue
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .attributeType)

        switch self {
        case .string(let stringValue):
            try container.encode(stringValue, forKey: .attributeValue)
        case .boolean(let boolValue):
            try container.encode(boolValue, forKey: .attributeValue)
        case .integer(let intValue):
            try container.encode(intValue, forKey: .attributeValue)
        case .double(let doubleValue):
            try container.encode(doubleValue, forKey: .attributeValue)
        case .array(let arrayValue):
            // Encode array of SentryAttribute by encoding their underlying AttributeValues
            let encodableArray = arrayValue.map { $0.attributeValue }
            try container.encode(encodableArray, forKey: .attributeValue)
        }
    }
}

extension AttributeValue: ExpressibleByStringLiteral {
    init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension AttributeValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: BooleanLiteralType) {
        self = .boolean(value)
    }
}

extension AttributeValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
}

extension AttributeValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}
