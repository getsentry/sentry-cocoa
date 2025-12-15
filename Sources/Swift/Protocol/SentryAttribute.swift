/// A protocol that allows types to be converted to a `SentryAttribute`.
///
/// Types conforming to this protocol can be used directly as attribute values
/// in metrics and logs. This enables using constants and variables directly
/// without explicit conversion.
///
/// Example:
/// ```swift
/// let endpoint = "api/users"
/// SentrySDK.metrics.count(key: "requests", value: 1, attributes: ["endpoint": endpoint])
/// ```
public protocol Attributable {
    /// Converts this value to a `SentryAttribute`.
    var asAttribute: SentryAttribute { get }
}

/// A type-safe value that can be stored in an attribute.
///
/// This enum provides type safety for attribute values while supporting
/// literal initialization via `ExpressibleByX` protocols.
public enum AttributeValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    case string(String)
    case boolean(Bool)
    case integer(Int)
    case double(Double)
    case array([any Attributable])
    
    /// The type identifier for this attribute value ("string", "boolean", "integer", "double", "string[]", "boolean[]", "integer[]", "double[]")
    public var type: String {
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
    public var anyValue: Any {
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
    
    /// Initializes from a string literal
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
    
    /// Initializes from a boolean literal
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .boolean(value)
    }
    
    /// Initializes from an integer literal
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
    
    /// Initializes from a float literal
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
    
    /// Creates an `AttributeValue` from any value, converting unsupported types to strings
    internal init(fromAny value: Any) {
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
        case let arrayValue as [Attributable]:
            self = .array(arrayValue)
        default:
            // For any other type, convert to string representation
            self = .string(String(describing: value))
        }
    }
}

/// A typed attribute that can be attached to structured item entries used by Logs & Metrics
///
/// `Attribute` provides a type-safe way to store structured data alongside item messages.
/// Supports String, Bool, Int, and Double types.
///
/// You can create attributes using literal syntax thanks to `ExpressibleByX` protocol support:
/// ```swift
/// let stringAttr: SentryAttribute = "hello"
/// let boolAttr: SentryAttribute = true
/// let intAttr: SentryAttribute = 42
/// let doubleAttr: SentryAttribute = 3.14159
/// ```
@objcMembers
public final class SentryAttribute: NSObject {
    /// The type-safe value stored in this attribute
    private let attributeValue: AttributeValue
    
    /// The type identifier for this attribute ("string", "boolean", "integer", "double")
    public var type: String {
        return attributeValue.type
    }
    
    /// The actual value stored in this attribute (for backward compatibility)
    /// - Note: Prefer using the type-safe initializers or literal syntax instead of accessing this property
    public var value: Any {
        return attributeValue.anyValue
    }

    public init(string value: String) {
        self.attributeValue = .string(value)
        super.init()
    }

    public init(boolean value: Bool) {
        self.attributeValue = .boolean(value)
        super.init()
    }

    public init(integer value: Int) {
        self.attributeValue = .integer(value)
        super.init()
    }

    public init(double value: Double) {
        self.attributeValue = .double(value)
        super.init()
    }

    /// Creates a double attribute from a float value
    public init(float value: Float) {
        self.attributeValue = .double(Double(value))
        super.init()
    }

    /// Creates a string array attribute
    public init(array value: [SentryAttribute]) {
        self.attributeValue = .array(value)
        super.init()
    }

    /// Creates an attribute from any value, converting unsupported types to strings.
    /// 
    /// This initializer is provided for backward compatibility. For type safety,
    /// prefer using the typed initializers (`init(string:)`, `init(boolean:)`, etc.)
    /// or literal syntax (e.g., `let attr: SentryAttribute = "value"`).
    /// 
    /// - Parameter value: The value to convert to an attribute. Supported types are
    ///                    String, Bool, Int, Double, and Float. Other types will be
    ///                    converted to their string representation.
    public init(value: Any) {
        self.attributeValue = AttributeValue(fromAny: value)
        super.init()
    }
}

// MARK: - Attributable Protocol Support

extension SentryAttribute: Attributable {
    public var asAttribute: SentryAttribute {
        return self
    }
}

// MARK: - Default Attributable Conformances

extension String: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(string: self)
    }
}

extension Bool: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(boolean: self)
    }
}

extension Int: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(integer: self)
    }
}

extension Double: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(double: self)
    }
}

extension Float: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(float: self)
    }
}

extension Array: Attributable where Element == String {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(stringArray: self)
    }
}

extension Array: Attributable where Element == Bool {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(booleanArray: self)
    }
}

extension Array: Attributable where Element == Int {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(integerArray: self)
    }
}

extension Array: Attributable where Element == Double {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(doubleArray: self)
    }
}

// MARK: - Expressible By Literal Support (for backward compatibility)

extension SentryAttribute: ExpressibleByStringLiteral {
    public convenience init(stringLiteral value: StringLiteralType) {
        self.init(string: value)
    }
}

extension SentryAttribute: ExpressibleByBooleanLiteral {
    public convenience init(booleanLiteral value: BooleanLiteralType) {
        self.init(boolean: value)
    }
}

extension SentryAttribute: ExpressibleByIntegerLiteral {
    public convenience init(integerLiteral value: IntegerLiteralType) {
        self.init(integer: value)
    }
}

extension SentryAttribute: ExpressibleByFloatLiteral {
    public convenience init(floatLiteral value: FloatLiteralType) {
        self.init(double: value)
    }
}

// MARK: - Internal Encodable Support
@_spi(Private) extension SentryAttribute: Encodable {
    private enum CodingKeys: String, CodingKey {
        case value
        case type
    }

    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)

        switch attributeValue {
        case .string(let stringValue):
            try container.encode(stringValue, forKey: .value)
        case .boolean(let boolValue):
            try container.encode(boolValue, forKey: .value)
        case .integer(let intValue):
            try container.encode(intValue, forKey: .value)
        case .double(let doubleValue):
            try container.encode(doubleValue, forKey: .value)
        case .stringArray(let arrayValue):
            try container.encode(arrayValue, forKey: .value)
        case .booleanArray(let arrayValue):
            try container.encode(arrayValue, forKey: .value)
        case .integerArray(let arrayValue):
            try container.encode(arrayValue, forKey: .value)
        case .doubleArray(let arrayValue):
            try container.encode(arrayValue, forKey: .value)
        }
    }
}
