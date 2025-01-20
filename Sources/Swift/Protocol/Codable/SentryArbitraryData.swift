@_implementationOnly import _SentryPrivate

enum SentryArbitraryData: Decodable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case date(Date)
    case dict([String: SentryArbitraryData])
    case array([SentryArbitraryData])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dateValue = try? container.decode(Date.self) {
            self = .date(dateValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let objectValue = try? container.decode([String: SentryArbitraryData].self) {
            self = .dict(objectValue)
        } else if let arrayValue = try? container.decode([SentryArbitraryData].self) {
            self = .array(arrayValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid JSON value"
            )
        }
    }
}

func decodeArbitraryData(decode: () throws -> [String: SentryArbitraryData]?) -> [String: Any]? {
    do {
        let rawData = try decode()
        return unwrapArbitraryData(rawData)
    } catch {
        SentryLog.error("Failed to decode raw data: \(error)")
        return nil
    }
}

func unwrapArbitraryData(_ dict: [String: SentryArbitraryData]?) -> [String: Any]? {
    guard let nonNullDict = dict else {
        return nil
    }
    
    var unwrappedDict = [String: Any]()
    nonNullDict.forEach { key, value in
        switch value {
        case .string(let stringValue):
            unwrappedDict[key] = stringValue
        case .number(let numberValue):
            unwrappedDict[key] = numberValue
        case .boolean(let boolValue):
            unwrappedDict[key] = boolValue
        case .date(let dateValue):
            unwrappedDict[key] = dateValue
        case .dict(let dictValue):
            unwrappedDict[key] = unwrapArbitraryData(dictValue)
        case .array(let arrayValue):
            unwrappedDict[key] = arrayValue
        case .null:
            unwrappedDict[key] = NSNull()
        }
    }
    
    return unwrappedDict
}
