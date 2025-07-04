@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(extras: [String: Any]) -> Data? {
        guard let data = SentrySerialization.data(withJSONObject: extras) else {
            SentrySDKLog.error("Failed to serialize extras, reason: extras is not valid json: \(extras)")
            return nil
        }
        return data
    }
    
    func decodeExtras(from data: Data) -> [String: Any]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize extras, reason: data is not valid json")
            return nil
        }

        return deserialized as? [String: Any]
    }
}
