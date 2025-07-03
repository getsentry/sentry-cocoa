extension SentryLog {
    public enum Attribute: Codable {
        case string(String)
        case boolean(Bool)
        case integer(Int)
        case double(Double)
        
        var type: String {
            switch self {
            case .string: return "string"
            case .boolean: return "boolean"
            case .integer: return "integer"
            case .double: return "double"
            }
        }
        
        var value: Any {
            switch self {
            case .string(let value): return value
            case .boolean(let value): return value
            case .integer(let value): return value
            case .double(let value): return value
            }
        }
        
        // MARK: - Initializers
        
        /// Initializes a SentryLog.Attribute from any value, converting it to the appropriate type
        init(value: Any) {
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
            case let cgFloatValue as CGFloat:
                self = .double(Double(cgFloatValue))
            case let nsNumberValue as NSNumber:
                // Handle NSNumber - need to check the underlying type
                if CFNumberIsFloatType(nsNumberValue) {
                    self = .double(nsNumberValue.doubleValue)
                } else {
                    self = .integer(nsNumberValue.intValue)
                }
            default:
                // For any other type, convert to string representation
                self = .string(String(describing: value))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case value
            case type
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "string":
                self = .string(try container.decode(String.self, forKey: .value))
            case "boolean":
                self = .boolean(try container.decode(Bool.self, forKey: .value))
            case "integer":
                self = .integer(try container.decode(Int.self, forKey: .value))
            case "double":
                self = .double(try container.decode(Double.self, forKey: .value))
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
            }
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
            }
        }
    }
}
