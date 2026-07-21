enum SentryDictionaryDecoder {
    // MARK: - Bool

    static func bool(_ dictionary: [String: Any], _ key: String) -> Bool? {
        guard let value = dictionary[key], !(value is NSNull) else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }

    static func isBool(_ number: NSNumber) -> Bool {
        String(cString: number.objCType) == "c" || String(cString: number.objCType) == "B"
    }

    // MARK: - UInt

    static func uint(_ dictionary: [String: Any], _ key: String) -> UInt? {
        guard let value = dictionary[key], !(value is NSNull), let number = value as? NSNumber else {
            return nil
        }
        guard number.intValue >= 0 else {
            return nil
        }
        return number.uintValue
    }

    // MARK: - Dictionary

    static func dictionary(_ dictionary: [String: Any], _ key: String) -> [String: Any]? {
        guard let value = dictionary[key], !(value is NSNull) else {
            return nil
        }
        return value as? [String: Any]
    }

    // MARK: - Array

    static func strings(_ dictionary: [String: Any], _ key: String) -> [String]? {
        guard let value = dictionary[key], !(value is NSNull) else {
            return nil
        }
        return (value as? [Any])?.compactMap { $0 as? String }
    }
}
