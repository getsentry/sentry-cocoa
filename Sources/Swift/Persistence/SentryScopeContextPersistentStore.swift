@_implementationOnly import _SentryPrivate

@objcMembers
class SentryScopeContextPersistentStore: NSObject {
    private let fileManager: SentryFileManager

    init(fileManager: SentryFileManager) {
        self.fileManager = fileManager
    }

    // MARK: - Context

    func moveContextFileToPreviousContextFile() {
        SentryLog.debug("Moving context file to previous context file")
        self.fileManager.moveState(contextFileURL.path, toPreviousState: previousContextFileURL.path)
    }

    func readPreviousContextFromDisk() -> [String: [String: Any]]? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: previousContextFileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: previousContextFileURL)
            return decodeContext(from: data)
        } catch {
            SentryLog.error("Failed to read context data from file at url: \(previousContextFileURL), reason: \(error)")
            return nil
        }
    }

    func writeContextToDisk(context: [String: [String: Any]]) {
        guard let data = encode(context: context) else {
            return
        }
        do {
            try data.write(to: contextFileURL, options: .atomic)
        } catch {
            SentryLog.error("Failed to write context data to file at path: \(contextFileURL), reason: \(error)")
        }
    }

    func deleteContextOnDisk() {
        SentryLog.debug("Deleting context file at path: \(contextFileURL.path)")
        let fm = FileManager.default
        guard fm.fileExists(atPath: contextFileURL.path) else {
            return
        }
        do {
            try fm.removeItem(atPath: contextFileURL.path)
        } catch {
            SentryLog.error("Failed to delete context file at path: \(contextFileURL.path), reason: \(error)")
        }
    }

    // MARK: - Encoding

    private func encode(context: [String: [String: Any]]) -> Data? {
        // We need to check if the context is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard JSONSerialization.isValidJSONObject(context) else {
            SentryLog.error("Failed to serialize context, reason: context is not valid json: \(context)")
            return nil
        }
        do {
            return try JSONSerialization.data(withJSONObject: context, options: [])
        } catch {
            SentryLog.error("Failed to serialize context, reason: \(error)")
            return nil
        }
    }

    private func decodeContext(from data: Data) -> [String: [String: Any]]? {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: Any]]
        } catch {
            SentryLog.error("Failed to deserialize context, reason: \(error)")
            return nil
        }
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
