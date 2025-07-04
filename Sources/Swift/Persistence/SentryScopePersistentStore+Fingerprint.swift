@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(fingerprint: [String]) -> Data? {
        // We need to check if the fingerprint is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard let data = SentrySerialization.data(withJSONObject: fingerprint) else {
            SentrySDKLog.error("Failed to serialize fingerprint, reason: fingerprint is not valid json: \(fingerprint)")
            return nil
        }
        return data
    }

    func decodeFingerprint(from data: Data) -> [String]? {
        guard let deserialized = SentrySerialization.deserializeArray(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize fingerprint, reason: data is not valid json")
            return nil
        }

        // Ensure all elements are strings
        let stringArray = deserialized.compactMap { $0 as? String }
        if stringArray.count != deserialized.count {
            SentrySDKLog.error("Failed to deserialize fingerprint, reason: not all elements are strings")
            return nil
        }

        return stringArray
    }
}
