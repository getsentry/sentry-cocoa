extension SentryLogAttribute: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case value
        case type
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        
        switch (type, value) {
        case ("string", let stringValue as String):
            try container.encode(stringValue, forKey: .value)
        case ("boolean", let booleanValue as Bool):
            try container.encode(booleanValue, forKey: .value)
        case ("integer", let integerValue as Int):
            try container.encode(integerValue, forKey: .value)
        case ("double", let doubleValue as Double):
            try container.encode(doubleValue, forKey: .value)
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath, debugDescription: "Unknown type: \(type)"))
        }
    }
    
    public convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(String.self, forKey: .type)
        let value: Any
        
        switch type {
        case "string":
            value = try container.decode(String.self, forKey: .value)
        case "boolean":
            value = try container.decode(Bool.self, forKey: .value)
        case "integer":
            value = try container.decode(Int.self, forKey: .value)
        case "double":
            value = try container.decode(Double.self, forKey: .value)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
        
        self.init(value: value, type: type)
    }
}
