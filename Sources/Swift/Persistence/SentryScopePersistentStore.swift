@_implementationOnly import _SentryPrivate

@objc
enum SentryScopeField: UInt, CaseIterable {
    case context
    case user
    case dist
    case environment
    
    var name: String {
        switch self {
        case .context:
            return "context"
        case .user:
            return "user"
        case .dist:
            return "dist"
        case .environment:
            return "environment"
        }
    }
}

@objc
@_spi(Private) public class SentryScopePersistentStore: NSObject {
    private let fileManager: SentryFileManagerProtocol
    
    @objc
    public init?(fileManager: SentryFileManagerProtocol?) {
        guard let fileManager else { return nil }
        
        self.fileManager = fileManager
    }
    
    // MARK: - General
    
    @objc
    public func moveAllCurrentStateToPreviousState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            moveCurrentFileToPreviousFile(field: field)
        }
    }
    
    func deleteAllCurrentState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            deleteCurrentFieldOnDisk(field: field)
        }
    }
    
    func deleteCurrentFieldOnDisk(field: SentryScopeField) {
        let path = currentFileURLFor(field: field).path
        SentrySDKLog.debug("Deleting context file at path: \(path)")
        fileManager.removeFile(atPath: path)
    }
    
    // Only used for testing
    func deleteAllPreviousState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            deletePreviousFieldOnDisk(field: field)
        }
    }
    
    // MARK: - Context
    
    @objc
    public func readPreviousContextFromDisk() -> [String: [String: Any]]? {
        readFieldFromDisk(field: .context) { data in
            decodeContext(from: data)
        }
    }
    
    func writeContextToDisk(context: [String: [String: Any]]) {
        writeFieldToDisk(field: .context, data: encode(context: context))
    }
    
    // MARK: - User
    @objc
    public func readPreviousUserFromDisk() -> User? {
        readFieldFromDisk(field: .user) { data in
            decodeUser(from: data)
        }
    }
    
    func writeUserToDisk(user: User) {
        writeFieldToDisk(field: .user, data: encode(user: user))
    }
    
    // MARK: - Dist
    @objc
    public func readPreviousDistFromDisk() -> String? {
        readFieldFromDisk(field: .dist) { data in
            decodeString(from: data)
        }
    }
    
    func writeDistToDisk(dist: String) {
        writeFieldToDisk(field: .dist, data: encode(string: dist))
    }
    
    // MARK: - User
    @objc
    public func readPreviousEnvironmentFromDisk() -> String? {
        readFieldFromDisk(field: .environment) { data in
            decodeString(from: data)
        }
    }
    
    func writeEnvironmentToDisk(environment: String) {
        writeFieldToDisk(field: .user, data: encode(string: environment))
    }
    
    // MARK: - Private Functions
    
    private func moveCurrentFileToPreviousFile(field: SentryScopeField) {
        SentrySDKLog.debug("Moving \(field.name) file to previous \(field.name) file")
        self.fileManager.moveState(currentFileURLFor(field: field).path, toPreviousState: previousFileURLFor(field: field).path)
    }
    
    private func deletePreviousFieldOnDisk(field: SentryScopeField) {
        let path = previousFileURLFor(field: field).path
        SentrySDKLog.debug("Deleting context file at path: \(path)")
        fileManager.removeFile(atPath: path)
    }
    
    private func writeFieldToDisk(field: SentryScopeField, data: Data?) {
        let path = currentFileURLFor(field: field).path
        SentrySDKLog.debug("Writing \(field.name) to disk at path: \(path)")
        guard let data = data else {
            return
        }
        fileManager.write(data, toPath: path)
    }
    
    private func readFieldFromDisk<T>(field: SentryScopeField, decode: (Data) -> T?) -> T? {
        let path = previousFileURLFor(field: field).path
        SentrySDKLog.debug("Reading previous \(field.name) file at path: \(path)")
        do {
            let data = try fileManager.readData(fromPath: path)
            return decode(data)
        } catch {
            SentrySDKLog.error("Failed to read previous \(field.name) file at path: \(path), reason: \(error)")
            return nil
        }
    }
    
    // MARK: - File Helpers
    
    /**
     * Path to a state file holding the latest data observed from the scope.
     *
     * This path is used to keep a persistent copy of the scope on disk, to be available after
     * restart of the app.
     */
    func currentFileURLFor(field: SentryScopeField) -> URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("\(field.name).state")
    }
    
    /**
     * Path to the previous state file holding the latest data observed from the scope.
     *
     * This file is overwritten at SDK start and kept as a copy of the last data file until the next
     * SDK start.
     */
    func previousFileURLFor(field: SentryScopeField) -> URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("previous.\(field.name).state")
    }
}

// MARK: - Context
extension SentryScopePersistentStore {
    private func encode(context: [String: [String: Any]]) -> Data? {
        // We need to check if the context is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard let sanitizedContext = sentry_sanitize(context) else {
            SentrySDKLog.error("Failed to sanitize context, reason: context is not valid json: \(context)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedContext) else {
            SentrySDKLog.error("Failed to serialize context, reason: context is not valid json: \(context)")
            return nil
        }
        return data
    }
    
    private func decodeContext(from data: Data) -> [String: [String: Any]]? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize context, reason: data is not valid json")
            return nil
        }
        
        // `SentrySerialization` is a wrapper around `NSJSONSerialization` which returns any type of data (`id`).
        // It is the casted to a `NSDictionary`, which is then casted to a `[AnyHashable: Any]` in Swift.
        //
        // The responsibility of validating and casting the deserialized data from any data to a dictionary is delegated
        // to the `SentrySerialization` class.
        //
        // As this decode context method specifically returns a dictionary of dictionaries, we need to ensure that
        // each value is a dictionary of type `[String: Any]`.
        //
        // If the deserialized value is not a dictionary, something clearly went wrong and we should discard the data.
        
        // Iterate through the deserialized dictionary and check if the type is a dictionary.
        // When all values are dictionaries, we can safely cast it to `[String: [String: Any]]` without allocating
        // additional memory (like when mapping values).
        for (key, value) in deserialized {
            guard value is [String: Any] else {
                SentrySDKLog.error("Failed to deserialize context, reason: value for key \(key) is not a valid dictionary")
                return nil
            }
        }
        
        return deserialized as? [String: [String: Any]]
    }
}

// MARK: - User
extension SentryScopePersistentStore {
    private func encode(user: User) -> Data? {
        guard let data = SentrySerialization.data(withJSONObject: user.serialize()) else {
            SentrySDKLog.error("Failed to serialize user, reason: user is not valid json: \(user)")
            return nil
        }
        return data
    }
    
    private func decodeUser(from data: Data) -> User? {
        return decoderUserHelper(data)
    }
    
    // Swift compiler can't infer T, even if I try to cast it
    private func decoderUserHelper(_ data: Data) -> UserDecodable? {
        return decodeFromJSONData(jsonData: data)
    }
}

// MARK: - Strings
extension SentryScopePersistentStore {
    private func encode(string: String) -> Data? {
        return string.data(using: .utf8)
    }
    
    private func decodeString(from data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}
