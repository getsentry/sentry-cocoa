/// A typed attribute that can be attached to structured item entries used by Logs & Metrics
///
/// `Attribute` provides a type-safe way to store structured data alongside item messages.
/// Supports String, Bool, Int, and Double types.
///
/// This class exists primarily for Objective-C compatibility, inheriting from `NSObject` and
/// using `@objcMembers` to ensure it can be used from Objective-C code. For Swift code, prefer
/// using the `SentryAttributeValue` protocol instead, which provides a more idiomatic Swift API
/// and allows you to pass native Swift types (String, Bool, Int, Double, Float, and their arrays)
/// directly without wrapping them in a class instance. This Objective-C-compatible class will be
/// removed in a future major version release.
@objcMembers
public final class SentryAttribute: NSObject {
    /// The type identifier for this attribute
    ///
    /// Can be any of the following:
    /// - `string`
    /// - `boolean`
    /// - `integer`
    /// - `double`
    /// - `array`
    public let type: String

    /// The actual value stored in this attribute
    public let value: Any

    /// Creates a string attribute with the specified value.
    ///
    /// - Parameter value: The string value to store in the attribute.
    public init(string value: String) {
        self.type = SentryAttributeType.string.rawValue
        self.value = value
        super.init()
    }

    /// Creates a boolean attribute with the specified value.
    ///
    /// - Parameter value: The boolean value to store in the attribute.
    public init(boolean value: Bool) {
        self.type = SentryAttributeType.boolean.rawValue
        self.value = value
        super.init()
    }

    /// Creates an integer attribute with the specified value.
    ///
    /// - Parameter value: The integer value to store in the attribute.
    public init(integer value: Int) {
        self.type = SentryAttributeType.integer.rawValue
        self.value = value
        super.init()
    }

    /// Creates a double attribute with the specified value.
    ///
    /// - Parameter value: The double value to store in the attribute.
    public init(double value: Double) {
        self.type = SentryAttributeType.double.rawValue
        self.value = value
        super.init()
    }

    /// Creates a double attribute from a float value
    ///
    /// - Parameter value: The float value to store in the attribute.
    public init(float value: Float) {
        self.type = SentryAttributeType.double.rawValue
        self.value = Double(value)
        super.init()
    }

    /// Creates a string array attribute with the specified values.
    ///
    /// - Parameter values: The array of string values to store in the attribute.
    public init(stringArray values: [String]) {
        self.type = SentryAttributeType.array.rawValue
        self.value = values
        super.init()
    }

    /// Creates a boolean array attribute with the specified values.
    ///
    /// - Parameter values: The array of boolean values to store in the attribute.
    public init(booleanArray values: [Bool]) {
        self.type = SentryAttributeType.array.rawValue
        self.value = values
        super.init()
    }

    /// Creates an integer array attribute with the specified values.
    ///
    /// - Parameter values: The array of integer values to store in the attribute.
    public init(integerArray values: [Int]) {
        self.type = SentryAttributeType.array.rawValue
        self.value = values
        super.init()
    }

    /// Creates a double array attribute with the specified values.
    ///
    /// - Parameter values: The array of double values to store in the attribute.
    public init(doubleArray values: [Double]) {
        self.type = SentryAttributeType.array.rawValue
        self.value = values
        super.init()
    }

    /// Creates a double attribute from a float value
    ///
    /// - Parameter values: The array of float values to store in the attribute.
    public init(floatArray values: [Float]) {
        self.type = SentryAttributeType.array.rawValue
        self.value = values.map(Double.init)
        super.init()
    }

    /// Creates an attribute from a SentryAttributeContent
    ///
    /// - Parameter attributableValue: The SentryAttributeContent to store in the attribute.
    internal init(attributableValue: SentryAttributeContent) {
        switch attributableValue {
        case .boolean(let value):
            self.type = SentryAttributeType.boolean.rawValue
            self.value = value
        case .string(let value):
            self.type = SentryAttributeType.string.rawValue
            self.value = value
        case .integer(let value):
            self.type = SentryAttributeType.integer.rawValue
            self.value = value
        case .double(let value):
            self.type = SentryAttributeType.double.rawValue
            self.value = value
        case .booleanArray(let array):
            self.type = SentryAttributeType.array.rawValue
            self.value = array
        case .stringArray(let array):
            self.type = SentryAttributeType.array.rawValue
            self.value = array
        case .integerArray(let array):
            self.type = SentryAttributeType.array.rawValue
            self.value = array
        case .doubleArray(let array):
            self.type = SentryAttributeType.array.rawValue
            self.value = array
        }
    }

    /// Creates an attribute from any value
    ///
    /// - Parameter value: The value to store in the attribute.
    internal init(value: Any) { // swiftlint:disable:this cyclomatic_complexity
        switch value {
        case let stringValue as String:
            self.type = SentryAttributeType.string.rawValue
            self.value = stringValue
        case let boolValue as Bool:
            self.type = SentryAttributeType.boolean.rawValue
            self.value = boolValue
        case let intValue as Int:
            self.type = SentryAttributeType.integer.rawValue
            self.value = intValue
        case let doubleValue as Double:
            self.type = SentryAttributeType.double.rawValue
            self.value = doubleValue
        case let floatValue as Float:
            self.type = SentryAttributeType.double.rawValue
            self.value = Double(floatValue)
        case let stringValues as [String]:
            self.type = SentryAttributeType.array.rawValue
            self.value = stringValues
        case let boolValues as [Bool]:
            self.type = SentryAttributeType.array.rawValue
            self.value = boolValues
        case let intValues as [Int]:
            self.type = SentryAttributeType.array.rawValue
            self.value = intValues
        case let doubleValues as [Double]:
            self.type = SentryAttributeType.array.rawValue
            self.value = doubleValues
        case let floatValues as [Float]:
            self.type = SentryAttributeType.array.rawValue
            self.value = floatValues.map(Double.init)
        case let attributable as SentryAttributeValue:
            let value = attributable.asSentryAttributeContent
            self.type = value.type
            self.value = value.anyValue
        case let attribute as SentryAttributeContent:
            self.type = attribute.type
            self.value = attribute.anyValue
        case let attribute as SentryAttribute:
            self.type = attribute.type
            self.value = attribute.value
        default:
            // For any other type, convert to string representation
            self.type = SentryAttributeType.string.rawValue
            self.value = String(describing: value)
        }
        super.init()
    }
}

// MARK: - Internal Encodable Support

@_spi(Private) extension SentryAttribute: Encodable {
    /// Encodes the attribute to a JSON encoder
    ///
    /// - Parameter encoder: The encoder to encode the attribute to.
    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        try self.asSentryAttributeContent.encode(to: encoder)
    }
}

@_spi(Private) extension SentryAttribute: SentryAttributeValue {
    /// Converts the attribute to a SentryAttributeContent
    ///
    /// - Returns: The SentryAttributeContent representation of the attribute.
    @_spi(Private) public var asSentryAttributeContent: SentryAttributeContent {
        switch self.type {
        case SentryAttributeType.string.rawValue:
            if let val = self.value as? String {
                return .string(val)
            }
        case SentryAttributeType.boolean.rawValue:
            if let val = self.value as? Bool {
                return .boolean(val)
            }
        case SentryAttributeType.integer.rawValue:
            if let val = self.value as? Int {
                return .integer(val)
            }
        case SentryAttributeType.double.rawValue:
            if let val = self.value as? Double {
                return .double(val)
            }
        case SentryAttributeType.array.rawValue:
            if let val = self.value as? [String] {
                return .stringArray(val)
            } else if let val = self.value as? [Bool] {
                return .booleanArray(val)
            } else if let val = self.value as? [Int] {
                return .integerArray(val)
            } else if let val = self.value as? [Double] {
                return .doubleArray(val)
            }
        default:
            break
        }
        return .string(String(describing: value))
    }
}
