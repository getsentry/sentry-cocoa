@_implementationOnly import _SentryPrivate

@objcMembers
@_spi(Private) public class SentryScopeFingerprintPersistentStore: SentryScopeBasePersistentStore {
    init(fileManager: SentryFileManagerProtocol) {
        super.init(fileManager: fileManager, fileName: "fingerprint")
    }

    // MARK: - Fingerprint

    public func readPreviousFingerprintFromDisk() -> [String]? {
        guard let data = super.readPreviousStateFromDisk() else {
            return nil
        }
        return decodeFingerprint(from: data)
    }

    func writeFingerprintToDisk(fingerprint: [String]) {
        guard let data = encode(fingerprint: fingerprint) else {
            return
        }
        super.writeStateToDisk(data: data)
    }

    func deleteFingerprintOnDisk() {
        super.deleteStateOnDisk()
    }

    func deletePreviousFingerprintOnDisk() {
        super.deletePreviousStateOnDisk()
    }

    // MARK: - Encoding

    private func encode(fingerprint: [String]) -> Data? {
        // We need to check if the fingerprint is a valid JSON object before encoding it.
        // Otherwise it will throw an unhandled `NSInvalidArgumentException` exception.
        // The error handler is required due but seems not to be executed.
        guard let data = SentrySerialization.data(withJSONObject: fingerprint) else {
            SentrySDKLog.error("Failed to serialize fingerprint, reason: fingerprint is not valid json: \(fingerprint)")
            return nil
        }
        return data
    }

    private func decodeFingerprint(from data: Data) -> [String]? {
        guard let deserialized = SentrySerialization.deserializeArray(fromJsonData: data) else {
            SentrySDKLog.error("Failed to deserialize fingerprint, reason: data is not valid json")
            return nil
        }
        
        // Ensure all elements are strings
        let stringArray = deserialized.compactMap { $0 as? String }
        if stringArray.count != deserialized.count {
            SentrySDKLog.error("Failed to deserialize fingerprint, reason: not all elements are strings")
            return nil
        }
        
        return stringArray
    }
} 
