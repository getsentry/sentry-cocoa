internal enum SentryAttributeType: String {
    case string = "string"
    case boolean = "boolean"
    case integer = "integer"
    case double = "double"
    case stringArray = "string[]"
    case booleanArray = "boolean[]"
    case integerArray = "integer[]"
    case doubleArray = "double[]"
}

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
            return SentryAttributeType.string.rawValue
        case .boolean:
            return SentryAttributeType.boolean.rawValue
        case .integer:
            return SentryAttributeType.integer.rawValue
        case .double:
            return SentryAttributeType.double.rawValue
        case .stringArray:
            return SentryAttributeType.stringArray.rawValue
        case .booleanArray:
            return SentryAttributeType.booleanArray.rawValue
        case .integerArray:
            return SentryAttributeType.integerArray.rawValue
        case .doubleArray:
            return SentryAttributeType.doubleArray.rawValue
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
    static func from(anyValue value: Any) -> Self { // swiftlint:disable:this cyclomatic_complexity
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
        if let val = value as? [String] {
            return .stringArray(val)
        }
        if let val = value as? [Bool] {
            return .booleanArray(val)
        }
        if let val = value as? [Int] {
            return .integerArray(val)
        }
        if let val = value as? [Double] {
            return .doubleArray(val)
        }
        if let val = value as? [Float] {
            return .doubleArray(val.map(Double.init))
        }
        if let val = value as? SentryAttributeValue {
            return val
        }
        if let val = value as? SentryAttribute {
            return val.asSentryAttributeValue
        }
        if let val = value as? SentryAttributeValuable {
            return val.asSentryAttributeValue
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

extension SentryAttributeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}

extension SentryAttributeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
}
