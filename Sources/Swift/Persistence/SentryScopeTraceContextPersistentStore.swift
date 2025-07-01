@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryScopeTraceContextPersistentStore: SentryScopeBasePersistentStore {
    public init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "traceContext")
    }

    // MARK: - Trace Context

    public func readPreviousTraceContextFromDisk() -> [String: Any]? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeTraceContext(from: data)
    }

    func writeTraceContextToDisk(traceContext: [String: Any]) {
        guard let data = encode(traceContext: traceContext) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    // MARK: - Encoding

    private func encode(traceContext: [String: Any]) -> Data? {
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

    private func decodeTraceContext(from data: Data) -> [String: Any]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize traceContext, reason: data is not valid json")
            return nil
        }
        return deserialized as? [String: Any]
    }
} 
