@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(extras: [String: Any]) -> Data? {
        guard let sanitizedExtras = sentry_sanitize(extras) else {
            SentrySDKLog.error("Failed to sanitize extras, reason: extras is not valid json: \(extras)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedExtras) else {
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

        guard let extras = deserialized as? [String: Any] else {
            // It should never fail here since all Dictionary JSON have strings as keys
            SentrySDKLog.error("Failed to deserialize extras, reason: data is not a dictionary: \(deserialized)")
            return nil
        }

        return extras
    }
}
