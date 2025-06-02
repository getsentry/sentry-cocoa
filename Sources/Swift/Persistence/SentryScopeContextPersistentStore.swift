@_implementationOnly import _SentryPrivate

@objcMembers
class SentryScopeContextPersistentStore: NSObject {
    private let fileManager: SentryFileManager

    init(fileManager: SentryFileManager) {
        self.fileManager = fileManager
    }

    // MARK: - Context

    func moveCurrentFileToPreviousFile() {
        SentryLog.debug("Moving context file to previous context file")
        self.fileManager.moveState(contextFileURL.path, toPreviousState: previousContextFileURL.path)
    }

    func readPreviousContextFromDisk() -> [String: [String: Any]]? {
        SentryLog.debug("Reading previous context file at path: \(previousContextFileURL.path)")
        do {
            let data = try fileManager.readData(fromPath: previousContextFileURL.path)
            return decodeContext(from: data)
        } catch {
            SentryLog.error("Failed to read previous context file at path: \(previousContextFileURL.path), reason: \(error)")
            return nil
        }
    }

    func writeContextToDisk(context: [String: [String: Any]]) {
        SentryLog.debug("Writing context to disk at path: \(contextFileURL.path)")
        guard let data = encode(context: context) else {
            return
        }
        fileManager.write(data, toPath: contextFileURL.path)
    }

    func deleteContextOnDisk() {
        SentryLog.debug("Deleting context file at path: \(contextFileURL.path)")
        fileManager.removeFile(atPath: contextFileURL.path)
    }

    func deletePreviousContextOnDisk() {
        SentryLog.debug("Deleting context file at path: \(contextFileURL.path)")
        fileManager.removeFile(atPath: previousContextFileURL.path)
    }

    // MARK: - Encoding

    private func encode(context: [String: [String: Any]]) -> Data? {
        // We need to check if the context is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard let sanitizedContext = sentry_sanitize(context) else {
            SentryLog.error("Failed to sanitize context, reason: context is not valid json: \(context)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedContext) else {
            SentryLog.error("Failed to serialize context, reason: context is not valid json: \(context)")
            return nil
        }
        return data
    }

    private func decodeContext(from data: Data) -> [String: [String: Any]]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentryLog.error("Failed to deserialize context, reason: data is not valid json")
            return nil
        }
        // Validate that the deserialized values are of the expected type.
        for (key, value) in deserialized {
            guard value is [String: Any] else {
                SentryLog.error("Failed to deserialize context, reason: value for key \(key) is not a valid dictionary")
                return nil
            }
        }
        return deserialized as? [String: [String: Any]]
    }

    // MARK: - Helpers

    /**
     * Path to a state file holding the latest context observed from the scope.
     *
     * This path is used to keep a persistent copy of the scope context on disk, to be available after
     * restart of the app.
     */
    var contextFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("context.state")
    }

    /**
     * Path to the previous state file holding the latest context observed from the scope.
     *
     * This file is overwritten at SDK start and kept as a copy of the last context file until the next
     * SDK start.
     */
    var previousContextFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("previous.context.state")
    }
}
