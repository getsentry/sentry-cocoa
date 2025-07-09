@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(fingerprint: [String]) -> Data? {
        return encode(fingerprint, "fingerprint", false)
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
