@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import Foundation

/// Manages file operations for Session Replay, including saving, moving, and cleaning up replay files.
// Helps reducing the login in SentrySessionReplayIntegration
struct SessionReplayFileManager {
    
    private enum Constants {
        static let replayFolder = "replay"
        static let currentReplay = "replay.current"
        static let lastReplay = "replay.last"
    }
    
    private let fileManager: SentryFileManager?
    private let sharedDispatchQueue: SentryDispatchQueueWrapper
    
    init(fileManager: SentryFileManager?, sharedDispatchQueue: SentryDispatchQueueWrapper) {
        self.fileManager = fileManager
        self.sharedDispatchQueue = sharedDispatchQueue
    }
    
    // MARK: - Directory Access
    
    func replayDirectory() -> URL? {
        guard let sentryPath = fileManager?.sentryPath else { return nil }
        return URL(fileURLWithPath: sentryPath).appendingPathComponent(Constants.replayFolder)
    }
    
    // MARK: - Session Info
    
    func saveCurrentSessionInfo(_ sessionId: SentryId, path: String, options: SentryReplayOptions) {
        SentrySDKLog.debug("[Session Replay] Saving current session info for session: \(sessionId) to path: \(path)")
        
        let info: [String: Any] = [
            "replayId": sessionId.sentryIdString,
            "path": (path as NSString).lastPathComponent,
            "errorSampleRate": options.onErrorSampleRate
        ]

        guard let data = SentrySerializationSwift.data(withJSONObject: info) else {
            SentrySDKLog.error("[Session Replay] Failed to serialize session info")
            return
        }

        let infoPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(Constants.currentReplay)
        removeFileIfExists(atPath: infoPath)
        do {
            try data.write(to: URL(fileURLWithPath: infoPath), options: .atomic)
            SentrySDKLog.debug("[Session Replay] Saved current session info at path: \(infoPath)")
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to write session info to path: \(infoPath), error: \(error)")
        }
        let crashInfoPath = (path as NSString).appendingPathComponent("crashInfo")
        sentrySessionReplaySync_start(crashInfoPath)
    }
    
    func lastReplayInfo() -> [String: Any]? {
        guard let dir = replayDirectory() else { return nil }
        let lastReplayUrl = dir.appendingPathComponent(Constants.lastReplay)
        guard let lastReplay = try? Data(contentsOf: lastReplayUrl) else {
            SentrySDKLog.debug("[Session Replay] No last replay info found")
            return nil
        }
        return SentrySerialization.deserializeDictionary(fromJsonData: lastReplay) as? [String: Any]
    }
    
    // MARK: - Session Directory
    
    func createSessionDirectory() -> URL? {
        guard let docs = replayDirectory() else {
            SentrySDKLog.error("[Session Replay] Could not get replay directory")
            return nil
        }

        let currentSession = UUID().uuidString
        let sessionDocs = docs.appendingPathComponent(currentSession)

        if !FileManager.default.fileExists(atPath: sessionDocs.path) {
            SentrySDKLog.debug("[Session Replay] Creating directory at path: \(sessionDocs.path)")
            do {
                try FileManager.default.createDirectory(
                    at: sessionDocs,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                SentrySDKLog.error("[Session Replay] Failed to create directory at path: \(sessionDocs.path), error: \(error)")
                return nil
            }
        }

        return sessionDocs
    }
    
    // MARK: - File Movement
    
    func moveCurrentReplay() {
        SentrySDKLog.debug("[Session Replay] Moving current replay")
        guard let path = replayDirectory() else { return }

        let current = path.appendingPathComponent(Constants.currentReplay)
        let last = path.appendingPathComponent(Constants.lastReplay)

        removeFileIfExists(at: last)
        moveFileIfExists(from: current, to: last)
    }
    
    // MARK: - Cleanup
    
    func cleanUp() {
        SentrySDKLog.debug("[Session Replay] Cleaning up")
        guard let replayDir = replayDirectory(), let fileManager = fileManager else { return }

        let lastReplayFolder = lastReplayInfo()?["path"] as? String
        // Mapping replay folder here and not in dispatched queue to prevent a race condition between
        // listing files and creating a new replay session.
        let replayFiles = fileManager.allFilesInFolder(replayDir.path)

        guard !replayFiles.isEmpty else {
            SentrySDKLog.debug("[Session Replay] No replay files to clean up")
            return
        }

        sharedDispatchQueue.dispatchAsync {
            self.removeOldReplayFiles(replayFiles, in: replayDir, excluding: lastReplayFolder, fileManager: fileManager)
        }
    }
    
    private func removeOldReplayFiles(
        _ files: [String],
        in directory: URL,
        excluding lastFolder: String?,
        fileManager: SentryFileManager
    ) {
        for file in files {
            // Skip the last replay folder.
            if file == lastFolder {
                SentrySDKLog.debug("[Session Replay] Skipping last replay folder: \(file)")
                continue
            }

            // Check if the file is a directory before deleting it.
            let filePath = (directory.path as NSString).appendingPathComponent(file)
            if fileManager.isDirectory(filePath) {
                SentrySDKLog.debug("[Session Replay] Removing replay directory at path: \(filePath)")
                fileManager.removeFile(atPath: filePath)
            }
        }
    }
    
    // MARK: - File Utilities
    
    func removeFileIfExists(atPath path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        SentrySDKLog.debug("[Session Replay] Removing file at path: \(path)")
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to remove file at path: \(path), error: \(error)")
        }
    }
    
    func removeFileIfExists(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            SentrySDKLog.debug("[Session Replay] No file to remove at path: \(url)")
            return
        }
        SentrySDKLog.debug("[Session Replay] Removing file at path: \(url)")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to remove file at path: \(url), error: \(error)")
        }
    }
    
    private func moveFileIfExists(from source: URL, to destination: URL) {
        guard FileManager.default.fileExists(atPath: source.path) else {
            SentrySDKLog.debug("[Session Replay] No file to move at path: \(source)")
            return
        }
        SentrySDKLog.debug("[Session Replay] Moving file from: \(source) to: \(destination)")
        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to move file from: \(source) to: \(destination), error: \(error)")
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
