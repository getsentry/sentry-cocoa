/// A type-safe value that can be stored in an attribute.
enum AttributeValue {
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

    /// Creates an `AttributeValue` from any value, converting unsupported types to strings
    init(fromAny value: Any) { // swiftlint:disable:this cyclomatic_complexity
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
        case let stringArrayValue as [String]:
            self = .stringArray(stringArrayValue)
        case let boolArrayValue as [Bool]:
            self = .booleanArray(boolArrayValue)
        case let intArrayValue as [Int]:
            self = .integerArray(intArrayValue)
        case let doubleArrayValue as [Double]:
            self = .doubleArray(doubleArrayValue)
        case let floatArrayValue as [Float]:
            self = .doubleArray(floatArrayValue.map { Double($0) })
        case let arrayValue as [SentryAttribute]:
            // Convert homogeneous array of SentryAttribute to typed array
            if arrayValue.isEmpty {
                // Empty array defaults to string array
                self = .stringArray([])
            } else {
                let firstType = arrayValue[0].attributeValue.type
                let allSameType = arrayValue.allSatisfy { $0.attributeValue.type == firstType }
                
                if allSameType {
                    switch firstType {
                    case "string":
                        self = .stringArray(arrayValue.compactMap { $0.attributeValue.anyValue as? String })
                    case "boolean":
                        self = .booleanArray(arrayValue.compactMap { $0.attributeValue.anyValue as? Bool })
                    case "integer":
                        self = .integerArray(arrayValue.compactMap { $0.attributeValue.anyValue as? Int })
                    case "double":
                        self = .doubleArray(arrayValue.compactMap { $0.attributeValue.anyValue as? Double })
                    default:
                        // Mixed or unknown types, convert to string array
                        self = .stringArray(arrayValue.map { String(describing: $0.value) })
                    }
                } else {
                    // Mixed types, convert to string array
                    self = .stringArray(arrayValue.map { String(describing: $0.value) })
                }
            }
        default:
            // For any other type, convert to string representation
            self = .string(String(describing: value))
        }
    }
}

extension AttributeValue: Encodable {
    private enum CodingKeys: String, CodingKey {
        case attributeType = "type"
        case attributeValue = "value"
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
