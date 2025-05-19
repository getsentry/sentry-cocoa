@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryWatchdogTerminationContextProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let fileManager: SentryFileManager

    private var activeFilePath: String

    init(withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper, fileManager: SentryFileManager) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.fileManager = fileManager
        self.activeFilePath = fileManager.contextFilePathOne

        super.init()

        self.switchActiveFile()
    }

    func processContext(_ context: [String: Any]?) {
        SentryLog.debug("Setting context in background queue: \(context ?? [:])")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set context, reason: reference to context processor is nil")
                return
            }
            guard let context = context else {
                SentryLog.debug("Context is nil, deleting active file.")
                strongSelf.deleteActiveFile()
                return
            }
            guard let encodedData = strongSelf.encode(context: context) else {
                return
            }
            strongSelf.write(data: encodedData)
        }
    }

    func clear() {
        deleteFiles()
    }

    // MARK: - Helpers

    func switchActiveFile() {
        SentryLog.debug("Switching active file path to write context.")
        if activeFilePath == fileManager.contextFilePathOne {
            activeFilePath = fileManager.contextFilePathTwo
        } else {
            activeFilePath = fileManager.contextFilePathOne
        }
        SentryLog.debug("Active file path is now: \(activeFilePath)")

        // Create a fresh file for the new active path
        deleteActiveFile()
    }

    func deleteActiveFile() {
        deleteFile(atPath: activeFilePath)
    }

    func deleteFiles() {
        // The deletion attempts are in individual do-catch blocks because
        // we want to delete both files if they exist, even if one of them fails.
        SentryLog.debug("Deleting all context files")
        deleteFile(atPath: fileManager.contextFilePathOne)
        deleteFile(atPath: fileManager.contextFilePathTwo)
    }

    private func deleteFile(atPath path: String) {
        SentryLog.debug("Deleting context file at path: \(path)")
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
        } catch {
            SentryLog.error("Failed to delete context file at path: \(path), reason: \(error)")
        }
    }

    func encode(context: [String: Any]) -> Data? {
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

    func write(data: Data) {
        do {
            let activeFileURL = URL(fileURLWithPath: activeFilePath)
            try data.write(to: activeFileURL, options: .atomic)
        } catch {
            SentryLog.error("Failed to write context data to file at path: \(activeFilePath), reason: \(error)")
        }
    }
}
