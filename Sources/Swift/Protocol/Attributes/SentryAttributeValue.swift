/// A type-safe value that can be stored in an attribute.
public enum SentryAttributeValue {
    case string(String)
    case boolean(Bool)
    case integer(Int)
    case double(Double)
    case stringArray([String])
    case booleanArray([Bool])
    case integerArray([Int])
    case doubleArray([Double])

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
        case .stringArray:
            return "string[]"
        case .booleanArray:
            return "boolean[]"
        case .integerArray:
            return "integer[]"
        case .doubleArray:
            return "double[]"
        }
    }

    /// Returns the underlying value as `Any` for backward compatibility
    var value: Any {
        switch self {
        case .string(let value):
            return value
        case .boolean(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .stringArray(let value):
            return value
        case .booleanArray(let value):
            return value
        case .integerArray(let value):
            return value
        case .doubleArray(let value):
            return value
        }
    }

    static func from(anyValue: Any) -> Self {
        if let value = anyValue as? Self {
            return value
        }
        // Try protocol-based conversion for types conforming to SentryAttributable
        if let attributable = anyValue as? SentryAttributable {
            return attributable.asAttributeValue
        }

        // Fallback: Handle Objective-C bridged types and other special cases
        switch anyValue {
        case let stringValue as String:
            return .string(stringValue)
        case let boolValue as Bool:
            return .boolean(boolValue)
        case let intValue as Int:
            return .integer(intValue)
        case let doubleValue as Double:
            return .double(doubleValue)
        case let floatValue as Float:
            return .double(Double(floatValue))
        case let stringArrayValue as [String]:
            return .stringArray(stringArrayValue)
        case let boolArrayValue as [Bool]:
            return .booleanArray(boolArrayValue)
        case let intArrayValue as [Int]:
            return .integerArray(intArrayValue)
        case let doubleArrayValue as [Double]:
            return .doubleArray(doubleArrayValue)
        case let floatArrayValue as [Float]:
            return .doubleArray(floatArrayValue.map { Double($0) })
        default:
            return .string(String(describing: anyValue))
        }
    }
}

extension SentryAttributeValue: Encodable {
    private enum CodingKeys: String, CodingKey {
        case attributeType = "type"
        case attributeValue = "value"
    }

    public func encode(to encoder: any Encoder) throws {
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
        case .stringArray(let arrayValue):
            try container.encode(arrayValue, forKey: .attributeValue)
        case .booleanArray(let arrayValue):
            try container.encode(arrayValue, forKey: .attributeValue)
        case .integerArray(let arrayValue):
            try container.encode(arrayValue, forKey: .attributeValue)
        case .doubleArray(let arrayValue):
            try container.encode(arrayValue, forKey: .attributeValue)
        }
    }
}

extension SentryAttributeValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension SentryAttributeValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .boolean(value)
    }
}

extension SentryAttributeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
}

extension SentryAttributeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}
