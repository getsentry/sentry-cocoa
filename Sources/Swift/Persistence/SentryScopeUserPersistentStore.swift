@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryScopeUserPersistentStore: NSObject {
    private let fileManager: SentryFileManager

    init(fileManager: SentryFileManager) {
        self.fileManager = fileManager
    }

    // MARK: - User

    public func moveCurrentFileToPreviousFile() {
        SentryLog.debug("Moving user file to previous user file")
        self.fileManager.moveState(userFileURL.path, toPreviousState: previousUserFileURL.path)
    }

    public func readPreviousUserFromDisk() -> User? {
        SentryLog.debug("Reading previous user file at path: \(previousUserFileURL.path)")
        do {
            let data = try fileManager.readData(fromPath: previousUserFileURL.path)
            return decodeUser(from: data)
        } catch {
            SentryLog.error("Failed to read previous user file at path: \(previousUserFileURL.path), reason: \(error)")
            return nil
        }
    }

    func writeUserToDisk(user: User) {
        SentryLog.debug("Writing user to disk at path: \(userFileURL.path)")
        guard let data = encode(user: user) else {
            return
        }
        fileManager.write(data, toPath: userFileURL.path)
    }

    func deleteUserOnDisk() {
        SentryLog.debug("Deleting user file at path: \(userFileURL.path)")
        fileManager.removeFile(atPath: userFileURL.path)
    }

    func deletePreviousUserOnDisk() {
        SentryLog.debug("Deleting user file at path: \(userFileURL.path)")
        fileManager.removeFile(atPath: previousUserFileURL.path)
    }

    // MARK: - Encoding

    private func encode(user: User) -> Data? {
        guard let sanitizedUser = sentry_sanitize(user.serialize()) else {
            SentryLog.error("Failed to sanitize user, reason: user is not valid json: \(user)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedUser) else {
            SentryLog.error("Failed to serialize user, reason: user is not valid json: \(user)")
            return nil
        }
        return data
    }

    private func decodeUser(from data: Data) -> User? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentryLog.error("Failed to deserialize user, reason: data is not valid json")
            return nil
        }
        
        return User(dictionary: deserialized)
    }

    // MARK: - Helpers

    /**
     * Path to a state file holding the latest user observed from the scope.
     *
     * This path is used to keep a persistent copy of the scope user on disk, to be available after
     * restart of the app.
     */
    var userFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("user.state")
    }

    /**
     * Path to the previous state file holding the latest user observed from the scope.
     *
     * This file is overwritten at SDK start and kept as a copy of the last user file until the next
     * SDK start.
     */
    var previousUserFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("previous.user.state")
    }
}
