@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeLevelPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "level")
    }

    // MARK: - SentryLevel

    public func readPreviousLevelFromDisk() -> SentryLevel {
        guard let data = super.readPreviousStateFromDisk() else {
            return .error
        }
        return decodeLevel(from: data)
    }

    func writeLevelToDisk(level: SentryLevel) {
        guard let data = encode(level: level) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    func deleteLevelOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousLevelOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(level: SentryLevel) -> Data? {
        let levelAsString = SentryLevelHelper.nameForLevel(level)
        return levelAsString.data(using: .utf8)
    }

    private func decodeLevel(from data: Data) -> SentryLevel {
        guard let string = String(data: data, encoding: .utf8) else {
            return SentryLevel.error
        }

        return SentryLevelHelper.levelForName(string)
    }
}
