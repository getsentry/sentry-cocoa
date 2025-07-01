@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryScopeUserPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "user")
    }

    // MARK: - User

    public func readPreviousUserFromDisk() -> User? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeUser(from: data)
    }

    func writeUserToDisk(user: User) {
        guard let data = encode(user: user) else {
            return
        }
        super.writeStateToDisk(data: data)
    }
    
    func deleteUserOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousUserOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(user: User) -> Data? {
        guard let sanitizedUser = sentry_sanitize(user.serialize()) else {
            SentrySDKLog.error("Failed to sanitize user, reason: user is not valid json: \(user)")
            return nil
        }
        guard let data = SentrySerialization.data(withJSONObject: sanitizedUser) else {
            SentrySDKLog.error("Failed to serialize user, reason: user is not valid json: \(user)")
            return nil
        }
        return data
    }

    private func decodeUser(from data: Data) -> User? {
        guard let deserialized = SentrySerialization.deserializeDictionary(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize user, reason: data is not valid json")
            return nil
        }
        
        return User(dictionary: deserialized)
    }
}
