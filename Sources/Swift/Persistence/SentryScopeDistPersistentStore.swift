@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeDistPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "dist")
    }

    // MARK: - Dist

    public func readPreviousDistFromDisk() -> String? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeDist(from: data)
    }

    func writeDistToDisk(dist: String) {
        guard let data = encode(dist: dist) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    func deleteDistOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousDistOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(dist: String) -> Data? {
        return dist.data(using: .utf8)
    }

    private func decodeDist(from data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
} 
