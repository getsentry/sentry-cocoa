extension SentryLog.Attribute: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case value
        case type
    }
    
    func encode(to encoder: any Encoder) throws {
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
    
    init(from decoder: any Decoder) throws {
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
}
