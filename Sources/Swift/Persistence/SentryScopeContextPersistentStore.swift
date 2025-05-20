@_implementationOnly import _SentryPrivate

@objcMembers
class SentryScopeContextPersistentStore: NSObject {
    private let fileManager: SentryFileManager

    init(fileManager: SentryFileManager) {
        self.fileManager = fileManager
    }

    // MARK: - Context

    func readPreviousContextFromDisk() -> [String: [String: Any]]? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: contextFileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: contextFileURL)
            return decodeContext(from: data)
        } catch {
            SentryLog.error("Failed to read context data from file at path: \(contextFileURL), reason: \(error)")
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

    var contextFileURL: URL {
        return URL(fileURLWithPath: fileManager.contextFilePath)
    }
}
