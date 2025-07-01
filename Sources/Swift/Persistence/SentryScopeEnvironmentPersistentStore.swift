@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeEnvironmentPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "environment")
    }

    // MARK: - Environment

    public func readPreviousEnvironmentFromDisk() -> String? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeEnvironment(from: data)
    }

    func writeEnvironmentToDisk(environment: String) {
        guard let data = encode(environment: environment) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    func deleteEnvironmentOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousEnvironmentOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(environment: String) -> Data? {
        return environment.data(using: .utf8)
    }

    private func decodeEnvironment(from data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
} 
