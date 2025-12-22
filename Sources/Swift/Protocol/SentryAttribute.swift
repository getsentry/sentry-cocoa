/// A typed attribute that can be attached to structured item entries used by Logs
///
/// `Attribute` provides a type-safe way to store structured data alongside item messages.
/// Supports String, Bool, Int, and Double types.
@objcMembers
public final class SentryAttribute: NSObject {
    /// The type identifier for this attribute ("string", "boolean", "integer", "double")
    public let type: String
    /// The actual value stored in this attribute
    public let value: Any

    public init(string value: String) {
        self.type = "string"
        self.value = value
        super.init()
    }

    public init(boolean value: Bool) {
        self.type = "boolean"
        self.value = value
        super.init()
    }

    public init(integer value: Int) {
        self.type = "integer"
        self.value = value
        super.init()
    }

    public init(double value: Double) {
        self.type = "double"
        self.value = value
        super.init()
    }

    /// Creates a double attribute from a float value
    public init(float value: Float) {
        self.type = "double"
        self.value = Double(value)
        super.init()
    }

    public init(stringArray values: [String]) {
        self.type = "string[]"
        self.value = values
        super.init()
    }

    public init(booleanArray values: [Bool]) {
        self.type = "boolean[]"
        self.value = values
        super.init()
    }

    public init(integerArray values: [Int]) {
        self.type = "integer[]"
        self.value = values
        super.init()
    }

    public init(doubleArray values: [Double]) {
        self.type = "double[]"
        self.value = values
        super.init()
    }

    /// Creates a double attribute from a float value
    public init(floatArray values: [Float]) {
        self.type = "double[]"
        self.value = values.map(Double.init)
        super.init()
    }

    internal init(attributableValue: SentryAttributeValue) {
        switch attributableValue {
        case .boolean(let value):
            self.type = "boolean"
            self.value = value
        case .string(let value):
            self.type = "string"
            self.value = value
        case .integer(let value):
            self.type = "integer"
            self.value = value
        case .double(let value):
            self.type = "double"
            self.value = value
        case .booleanArray(let array):
            self.type = "boolean[]"
            self.value = array
        case .stringArray(let array):
            self.type = "string[]"
            self.value = array
        case .integerArray(let array):
            self.type = "integer[]"
            self.value = array
        case .doubleArray(let array):
            self.type = "double[]"
            self.value = array
        }
    }

    internal init(value: Any) { // swiftlint:disable:this cyclomatic_complexity
        switch value {
        case let stringValue as String:
            self.type = "string"
            self.value = stringValue
        case let boolValue as Bool:
            self.type = "boolean"
            self.value = boolValue
        case let intValue as Int:
            self.type = "integer"
            self.value = intValue
        case let doubleValue as Double:
            self.type = "double"
            self.value = doubleValue
        case let floatValue as Float:
            self.type = "double"
            self.value = Double(floatValue)
        case let stringValues as [String]:
            self.type = "string[]"
            self.value = stringValues
        case let boolValues as [Bool]:
            self.type = "boolean[]"
            self.value = boolValues
        case let intValues as [Int]:
            self.type = "integer[]"
            self.value = intValues
        case let doubleValues as [Double]:
            self.type = "double[]"
            self.value = doubleValues
        case let floatValues as [Float]:
            self.type = "double[]"
            self.value = floatValues.map(Double.init)
        case let attributable as SentryAttributeValuable:
            let value = attributable.asAttributeValue
            self.type = value.type
            self.value = value.anyValue
        case let attribute as SentryAttributeValue:
            self.type = attribute.type
            self.value = attribute.anyValue
        case let attribute as SentryAttribute:
            self.type = attribute.type
            self.value = attribute.value
        default:
            // For any other type, convert to string representation
            self.type = "string"
            self.value = String(describing: value)
        }
        super.init()
    }
}

// MARK: - Internal Encodable Support

@_spi(Private) extension SentryAttribute: Encodable {
    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        try self.asAttributeValue.encode(to: encoder)
    }
}

@_spi(Private) extension SentryAttribute: SentryAttributeValuable {
    @_spi(Private) public var asAttributeValue: SentryAttributeValue {
        switch self.type {
        case "string":
            if let val = self.value as? String {
                return .string(val)
            }
        case "boolean":
            if let val = self.value as? Bool {
                return .boolean(val)
            }
        case "integer":
            if let val = self.value as? Int {
                return .integer(val)
            }
        case "double":
            if let val = self.value as? Double {
                return .double(val)
            }
        case "string[]":
            if let val = self.value as? [String] {
                return .stringArray(val)
            }
        case "boolean[]":
            if let val = self.value as? [Bool] {
                return .booleanArray(val)
            }
        case "integer[]":
            if let val = self.value as? [Int] {
                return .integerArray(val)
            }
        case "double[]":
            if let val = self.value as? [Double] {
                return .doubleArray(val)
            }
        default:
            break
        }
        return .string(String(describing: value))
    }
}
