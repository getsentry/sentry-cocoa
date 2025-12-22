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

    internal init(value: Any) {
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
        case let attributable as SentryAttributeValuable:
            let value = attributable.asAttributeValue
            self.type = value.type
            self.value = value.anyValue
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
    private enum CodingKeys: String, CodingKey {
        case value
        case type
    }

    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)

        switch type {
        case "string":
            guard let stringValue = value as? String else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected String but got \(Swift.type(of: value))"))
            }
            try container.encode(stringValue, forKey: .value)
        case "boolean":
            guard let boolValue = value as? Bool else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Bool but got \(Swift.type(of: value))"))
            }
            try container.encode(boolValue, forKey: .value)
        case "integer":
            guard let intValue = value as? Int else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Int but got \(Swift.type(of: value))"))
            }
            try container.encode(intValue, forKey: .value)
        case "double":
            guard let doubleValue = value as? Double else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Expected Double but got \(Swift.type(of: value))"))
            }
            try container.encode(doubleValue, forKey: .value)
        default:
            try container.encode(String(describing: value), forKey: .value)
        }
    }
}
