extension SentryLog {
    enum Attribute {
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
    }
}
