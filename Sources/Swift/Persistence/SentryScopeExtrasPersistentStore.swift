@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeExtrasPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "extras")
    }

    // MARK: - Extras

    public func readPreviousExtrasFromDisk() -> [String: Any]? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeExtras(from: data)
    }

    func writeExtrasToDisk(extras: [String: Any]) {
        guard let data = encode(extras: extras) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    // MARK: - Encoding

    private func encode(extras: [String: Any]) -> Data? {
        // We need to check if the extras is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
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

    private func decodeExtras(from data: Data) -> [String: Any]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize extras, reason: data is not valid json")
            return nil
        }
        
        return deserialized as? [String: Any]
    }
} 
