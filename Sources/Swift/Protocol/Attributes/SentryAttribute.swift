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
    let attributeValue: AttributeValue

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
