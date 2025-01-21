@_implementationOnly import _SentryPrivate

enum ArbitraryData: Decodable {
    case string(String)
    case int(Int)
    case number(Double)
    case boolean(Bool)
    case date(Date)
    case dict([String: ArbitraryData])
    case array([ArbitraryData])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dateValue = try? container.decode(Date.self) {
            self = .date(dateValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let objectValue = try? container.decode([String: ArbitraryData].self) {
            self = .dict(objectValue)
        } else if let arrayValue = try? container.decode([ArbitraryData].self) {
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

func decodeArbitraryData(decode: () throws -> [String: ArbitraryData]?) -> [String: Any]? {
    do {
        let rawData = try decode()
        return unwrapArbitraryDict(rawData)
    } catch {
        SentryLog.error("Failed to decode raw data: \(error)")
        return nil
    }
}

private func unwrapArbitraryDict(_ dict: [String: ArbitraryData]?) -> [String: Any]? {
    guard let nonNullDict = dict else {
        return nil
    }
    
    return nonNullDict.mapValues { unwrapArbitraryValue($0) as Any }
}

private func unwrapArbitraryArray(_ array: [ArbitraryData]?) -> [Any]? {
    guard let nonNullArray = array else {
        return nil
    }

    return nonNullArray.map { unwrapArbitraryValue($0) as Any }
}

private func unwrapArbitraryValue(_ value: ArbitraryData?) -> Any? {
    switch value {
    case .string(let stringValue):
        return stringValue
    case .number(let numberValue):
        return numberValue
    case .int(let intValue):
        return intValue
    case .boolean(let boolValue):
        return boolValue
    case .date(let dateValue):
        return dateValue
    case .dict(let dictValue):
        return unwrapArbitraryDict(dictValue)
    case .array(let arrayValue):
        return unwrapArbitraryArray(arrayValue)
    case .null:
        return NSNull()
    case .none:
        return nil
    }
}
