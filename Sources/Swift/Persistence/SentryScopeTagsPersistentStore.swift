@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeTagsPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "tags")
    }

    // MARK: - Tags

    public func readPreviousTagsFromDisk() -> [String: String]? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeTags(from: data)
    }

    func writeTagsToDisk(tags: [String: String]) {
        guard let data = encode(tags: tags) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    func deleteTagsOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousTagsOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(tags: [String: String]) -> Data? {
        // We need to check if the Tags is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard let sanitizedTags = sentry_sanitize(tags) else {
            SentrySDKLog.error("Failed to sanitize tags, reason: tags is not valid json: \(tags)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedTags) else {
            SentrySDKLog.error("Failed to serialize tags, reason: tags is not valid json: \(tags)")
            return nil
        }
        return data
    }

    private func decodeTags(from data: Data) -> [String: String]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize tags, reason: data is not valid json")
            return nil
        }

        // `SentrySerialization` is a wrapper around `NSJSONSerialization` which returns any type of data (`id`).
        // It is the casted to a `NSDictionary`, which is then casted to a `[AnyHashable: Any]` in Swift.
        //
        // The responsibility of validating and casting the deserialized data from any data to a dictionary is delegated
        // to the `SentrySerialization` class.
        //
        // As this decode Tags method specifically returns a dictionary of strings, we need to ensure that
        // each value is a string.
        //
        // If the deserialized value is not a string, something clearly went wrong and we should discard the data.
        
        // Iterate through the deserialized dictionary and check if the type is a dictionary.
        // When all values are strings, we can safely cast it to `[String: String]` without allocating
        // additional memory (like when mapping values).
        for (key, value) in deserialized {
            guard value is String else {
                SentrySDKLog.error("Failed to deserialize tags, reason: value for key \(key) is not a valid string")
                return nil
            }
        }

        return deserialized as? [String: String]
    }
}
