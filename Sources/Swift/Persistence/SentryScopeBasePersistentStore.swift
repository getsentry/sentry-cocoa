@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryScopeBasePersistentStore: NSObject {
    private let fileManager: SentryFileManagerProtocol
    private let fileName: String

    init(fileManager: SentryFileManagerProtocol, fileName: String) {
        self.fileManager = fileManager
        self.fileName = fileName
    }

    // MARK: - State Manipulation

    public func moveCurrentFileToPreviousFile() {
        SentrySDKLog.debug("Moving \(fileName) file to previous \(fileName) file")
        self.fileManager.moveState(currentFileURL.path, toPreviousState: previousFileURL.path)
    }

    public func readPreviousStateFromDisk() -> Data? {
        SentrySDKLog.debug("Reading previous \(fileName) file at path: \(previousFileURL.path)")
        do {
            return try fileManager.readData(fromPath: previousFileURL.path)
        } catch {
            SentrySDKLog.error("Failed to read previous \(fileName) file at path: \(previousFileURL.path), reason: \(error)")
            return nil
        }
    }

    func writeStateToDisk(data: Data) {
        SentrySDKLog.debug("Writing \(fileName) to disk at path: \(currentFileURL.path)")
        fileManager.write(data, toPath: currentFileURL.path)
    }

    func deleteStateOnDisk() {
        SentrySDKLog.debug("Deleting \(fileName) file at path: \(currentFileURL.path)")
        fileManager.removeFile(atPath: currentFileURL.path)
    }

    func deletePreviousStateOnDisk() {
        SentrySDKLog.debug("Deleting \(fileName) file at path: \(previousFileURL.path)")
        fileManager.removeFile(atPath: previousFileURL.path)
    }

    // MARK: - Helpers

    /**
     * Path to a state file holding the latest state observed from the scope.
     *
     * This path is used to keep a persistent copy of the scope state on disk, to be available after
     * restart of the app.
     */
    var currentFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("\(self.fileName).state")
    }

    /**
     * Path to the previous state file holding the latest state observed from the scope.
     *
     * This file is overwritten at SDK start and kept as a copy of the last state file until the next
     * SDK start.
     */
    var previousFileURL: URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("previous.\(self.fileName).state")
    }
}
