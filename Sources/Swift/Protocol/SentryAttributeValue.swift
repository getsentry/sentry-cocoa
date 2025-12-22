public enum SentryAttributeValue: Equatable, Hashable {
    case string(String)
    case boolean(Bool)
    case integer(Int)
    case double(Double)
    case stringArray([String])
    case booleanArray([Bool])
    case integerArray([Int])
    case doubleArray([Double])

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
}

extension SentryAttributeValue: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode(value, forKey: .value)
        case .integer(let value):
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode(value, forKey: .value)
        case .stringArray(let value):
            try container.encode(value, forKey: .value)
        case .booleanArray(let value):
            try container.encode(value, forKey: .value)
        case .integerArray(let value):
            try container.encode(value, forKey: .value)
        case .doubleArray(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

extension SentryAttributeValue {
    static func from(anyValue value: Any) -> Self {
        if let val = value as? String {
            return .string(val)
        }
        if let val = value as? Bool {
            return .boolean(val)
        }
        if let val = value as? Int {
            return .integer(val)
        }
        if let val = value as? Double {
            return .double(val)
        }
        if let val = value as? Float {
            return .double(Double(val))
        }
        if let val = value as? SentryAttributeValue {
            return val
        }
        return .string(String(describing: value))
    }

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
}
