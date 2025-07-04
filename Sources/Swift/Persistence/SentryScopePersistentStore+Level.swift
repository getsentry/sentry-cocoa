extension SentryScopePersistentStore {
    func encode(level: NSNumber) -> Data? {
        let rawValue = level.uintValue
        return Data("\(rawValue)".utf8)
    }
    
    func decodeLevel(from data: Data) -> SentryLevel? {
        if let stringValue = String(data: data, encoding: .utf8),
           let intValue = UInt(stringValue),
            let level = SentryLevel(rawValue: intValue) {
            return level
        } else {
            return nil
        }
    }
}
