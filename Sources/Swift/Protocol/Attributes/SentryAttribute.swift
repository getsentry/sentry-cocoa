/// A typed attribute that can be attached to structured item entries used by Logs & Metrics
///
/// `Attribute` provides a type-safe way to store structured data alongside item messages.
/// Supports String, Bool, Int, Double types and their homogeneous arrays (String[], Bool[], Int[], Double[]).
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
    fileprivate let wrappedValue: SentryAttributeValue

    /// The type identifier for this attribute ("string", "boolean", "integer", "double", "string[]", "boolean[]", "integer[]", "double[]")
    public var type: String {
        return wrappedValue.type
    }
    
    /// The actual value stored in this attribute (for backward compatibility)
    /// - Note: Prefer using the type-safe initializers or literal syntax instead of accessing this property
    public var value: Any {
        return wrappedValue.value
    }

    public init(string value: String) {
        self.wrappedValue = .string(value)
        super.init()
    }

    public init(boolean value: Bool) {
        self.wrappedValue = .boolean(value)
        super.init()
    }

    public init(integer value: Int) {
        self.wrappedValue = .integer(value)
        super.init()
    }

    public init(double value: Double) {
        self.wrappedValue = .double(value)
        super.init()
    }

    /// Creates a double attribute from a float value
    public init(float value: Float) {
        self.wrappedValue = .double(Double(value))
        super.init()
    }

    /// Creates a string array attribute
    public init(stringArray value: [String]) {
        self.wrappedValue = .stringArray(value)
        super.init()
    }

    /// Creates a boolean array attribute
    public init(booleanArray value: [Bool]) {
        self.wrappedValue = .booleanArray(value)
        super.init()
    }

    /// Creates an integer array attribute
    public init(integerArray value: [Int]) {
        self.wrappedValue = .integerArray(value)
        super.init()
    }

    /// Creates a double array attribute
    public init(doubleArray value: [Double]) {
        self.wrappedValue = .doubleArray(value)
        super.init()
    }

    /// Creates a float array attribute (converted to double array)
    public init(floatArray value: [Float]) {
        self.wrappedValue = .doubleArray(value.map { Double($0) })
        super.init()
    }

    /// Creates an array attribute from an array of SentryAttribute.
    /// 
    /// The array must be homogeneous (all elements of the same type).
    /// If the array is empty or contains mixed types, it will be converted to a string array.
    public init(array value: [SentryAttribute]) {
        wrappedValue = value.asAttributeValue
        super.init()
    }

    /// Internal initializer to allow direct creation from `SentryAttributeValue`.
    /// This enables protocol-based conversion without going through `init(value: Any)`.
    internal init(wrappedValue: SentryAttributeValue) {
        self.wrappedValue = wrappedValue
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
        // First, try protocol-based conversion for types conforming to SentryAttributable
        if let attributable = value as? SentryAttributable {
            self.wrappedValue = attributable.asAttributeValue
            super.init()
            return
        }
        
        // Fallback: Handle Objective-C bridged types and other special cases
        switch value {
        case let stringValue as String:
            wrappedValue = .string(stringValue)
        case let nsStringValue as NSString:
            // NSString bridges to String but doesn't conform to SentryAttributable
            wrappedValue = .string(nsStringValue as String)
        case let boolValue as Bool:
            wrappedValue = .boolean(boolValue)
        case let intValue as Int:
            wrappedValue = .integer(intValue)
        case let doubleValue as Double:
            wrappedValue = .double(doubleValue)
        case let floatValue as Float:
            wrappedValue = .double(Double(floatValue))
        case let stringArrayValue as [String]:
            wrappedValue = .stringArray(stringArrayValue)
        case let boolArrayValue as [Bool]:
            wrappedValue = .booleanArray(boolArrayValue)
        case let intArrayValue as [Int]:
            wrappedValue = .integerArray(intArrayValue)
        case let doubleArrayValue as [Double]:
            wrappedValue = .doubleArray(doubleArrayValue)
        case let floatArrayValue as [Float]:
            wrappedValue = .doubleArray(floatArrayValue.map { Double($0) })
        default:
            // For any other type, convert to string representation
            wrappedValue = .string(String(describing: value))
        }
        super.init()
    }
}

// MARK: - Attributable Protocol Support

extension SentryAttribute: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return self.wrappedValue
    }
}

// MARK: - Encodable Support

extension SentryAttribute: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}
