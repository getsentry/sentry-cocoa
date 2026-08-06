// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryWatchdogTerminationBreadcrumbProcessor: AnyObject {
    func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any])
    func clear()
    func clearBreadcrumbs()
    func flushAndClose()
}

extension SentryDefaultWatchdogTerminationBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor {}
#else
typealias SentryWatchdogTerminationBreadcrumbProcessor = SentryDefaultWatchdogTerminationBreadcrumbProcessor
#endif

final class SentryDefaultWatchdogTerminationBreadcrumbProcessor {
    private static let newlineData = Data("\n".utf8)

    private let fileManager: SentryFileManager?
    private let maxBreadcrumbs: Int
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper

    private var fileHandle: FileHandle?
    private var activeFilePath: String?
    private var breadcrumbCounter = 0

    // The file handle is opened lazily, so nil is valid before the first breadcrumb and after a
    // failed file open. When the watchdog integration is uninstalled, it drains pending writes and
    // closes the handle. Marking the processor as closed prevents subsequent scope-observer calls
    // from creating a new handle and writing breadcrumbs after the SDK has shut down.
    private var isClosed = false

    init(
        maxBreadcrumbs: Int,
        fileManager: SentryFileManager?,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.maxBreadcrumbs = maxBreadcrumbs
        self.fileManager = fileManager
        self.dispatchQueueWrapper = dispatchQueueWrapper
    }

    deinit {
        closeFileHandle()
    }

    func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any]) {
        SentrySDKLog.debug("Adding breadcrumb: \(crumb)")
        
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let self, !isClosed else { return }
            guard let jsonData = SentrySerializationSwift.data(withJSONObject: crumb) else {
                SentrySDKLog.error("Error serializing breadcrumb to JSON")
                return
            }

            storeBreadcrumb(jsonData)
        }
    }

    func clear() {
        clearBreadcrumbs()
    }

    func clearBreadcrumbs() {
        SentrySDKLog.debug("Clearing breadcrumb files")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let self, !isClosed else { return }

            deleteFiles()
            switchFileHandle()
        }
    }

    func flushAndClose() {
        dispatchQueueWrapper.dispatchSync { [self] in
            SentrySDKLog.debug("Flushing and closing breadcrumb file handle")
            isClosed = true
            closeFileHandle()
        }
    }

    private func switchFileHandle() {
        guard let fileManager else {
            SentrySDKLog.error("Cannot switch breadcrumb file handle because the file manager is nil")
            return
        }
        closeFileHandle()

        if activeFilePath == fileManager.breadcrumbsFilePathOne {
            activeFilePath = fileManager.breadcrumbsFilePathTwo
        } else {
            activeFilePath = fileManager.breadcrumbsFilePathOne
        }
        guard let activeFilePath else {
            SentrySDKLog.error("Cannot switch breadcrumb file handle because the active file path is nil")
            return
        }

        SentrySDKLog.debug("Switching breadcrumb file handle to \(activeFilePath)")
        fileManager.removeFile(atPath: activeFilePath)
        guard fileManager.write(Data(), toPath: activeFilePath) else {
            SentrySDKLog.error("Couldn't create breadcrumb file at \(activeFilePath)")
            return
        }
        fileHandle = FileHandle(forWritingAtPath: activeFilePath)

        if fileHandle == nil {
            SentrySDKLog.error("Couldn't open file handle for \(activeFilePath)")
        }
    }

    private func deleteFiles() {
        SentrySDKLog.debug("Deleting files")
        closeFileHandle()
        activeFilePath = nil
        breadcrumbCounter = 0

        guard let fileManager else {
            SentrySDKLog.error("Cannot delete breadcrumb files because the file manager is nil")
            return
        }

        fileManager.removeFile(atPath: fileManager.breadcrumbsFilePathOne)
        fileManager.removeFile(atPath: fileManager.breadcrumbsFilePathTwo)
    }

    private func storeBreadcrumb(_ data: Data) {
        SentrySDKLog.debug("Storing breadcrumb data with \(data.count) bytes")
        guard let fileHandle = fileHandleForWriting() else { return }

        var fileSize: UInt64 = 0

        do {
            fileSize = try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
            try fileHandle.write(contentsOf: Self.newlineData)
            breadcrumbCounter += 1
        } catch {
            SentrySDKLog.error("Error while writing data to end file with size (\(fileSize)): \(error)")
        }

        if breadcrumbCounter >= maxBreadcrumbs {
            switchFileHandle()
            breadcrumbCounter = 0
        }
    }

    private func fileHandleForWriting() -> FileHandle? {
        if fileHandle == nil {
            switchFileHandle()
        }

        return fileHandle
    }

    private func closeFileHandle() {
        guard let fileHandle else { return }

        SentrySDKLog.debug("Closing file handle")
        fileHandle.closeFile()
        self.fileHandle = nil
    }
}
// swiftlint:enable missing_docs
