@_implementationOnly import _SentryPrivate

extension SentryScopePersistentStore {
    func encode(traceContext: [String: Any]) -> Data? {
        guard let sanitized = sentry_sanitize(traceContext) else {
            SentrySDKLog.error("Failed to sanitize traceContext, reason: not valid json: \(traceContext)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitized) else {
            SentrySDKLog.error("Failed to serialize traceContext, reason: not valid json: \(traceContext)")
            return nil
        }
        return data
    }
    
    func decodeTraceContext(from data: Data) -> [String: Any]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize traceContext, reason: data is not valid json")
            return nil
        }
        return deserialized as? [String: Any]
    }
}
