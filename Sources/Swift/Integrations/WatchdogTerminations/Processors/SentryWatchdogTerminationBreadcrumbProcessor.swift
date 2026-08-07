// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

typealias SerializedBreadcrumb = [AnyHashable: Any]

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryWatchdogTerminationBreadcrumbProcessor {
    func addSerializedBreadcrumb(_ crumb: SerializedBreadcrumb)
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

    private let fileManager: SentryFileManager
    private let maxBreadcrumbs: Int
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper

    private var fileHandle: FileHandle?
    private var currentFilePath: String
    private var breadcrumbCounter = 0

    // The file handle is opened lazily, so nil is valid before the first breadcrumb and after a
    // failed file open. When the watchdog integration is uninstalled, it drains pending writes and
    // closes the handle. Marking the processor as closed prevents subsequent scope-observer calls
    // from creating a new handle and writing breadcrumbs after the SDK has shut down.
    private var shouldProcessIncomingCrumbs = true

    init(
        maxBreadcrumbs: Int,
        fileManager: SentryFileManager,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.maxBreadcrumbs = maxBreadcrumbs
        self.fileManager = fileManager
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.currentFilePath = fileManager.breadcrumbsFilePathOne
    }

    deinit {
        // In normal operation fileHandle is already nil because the processor is closed via
        // rotateToPreviousSession() or flushAndClose() before being released. If it is non-nil
        // here, the processor was dropped without being closed; any work still queued on the
        // serial queue has already been abandoned (the [weak self] blocks nil-guard out once
        // deinit begins). Close the handle directly on the deallocating thread as a best-effort
        // resource cleanup.
        if fileHandle != nil {
            SentrySDKLog.debug("BreadcrumbProcessor deallocated without being closed — closing file handle on deallocating thread")
            closeFileHandle()
        }
    }

    func addSerializedBreadcrumb(_ crumb: SerializedBreadcrumb) {
        SentrySDKLog.debug("Adding breadcrumb: \(crumb)")
        
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let self, shouldProcessIncomingCrumbs else { return }
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
            guard let self, shouldProcessIncomingCrumbs else { return }

            deleteFiles()
        }
    }

    func flushAndClose() {
        dispatchQueueWrapper.dispatchSync { [self] in
            guard shouldProcessIncomingCrumbs else { return }
            SentrySDKLog.debug("Flushing and closing breadcrumb file handle")

            shouldProcessIncomingCrumbs = false
            closeFileHandle()

            SentrySDKLog.debug("Rotating breadcrumb files to previous session")

            fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
            resetCurrentFilePath()
            breadcrumbCounter = 0
        }
    }

    private func resetCurrentFilePath() {
        currentFilePath = fileManager.breadcrumbsFilePathOne
    }

    private func switchCurrentFilePath() {
        currentFilePath = if currentFilePath == fileManager.breadcrumbsFilePathOne {
            fileManager.breadcrumbsFilePathTwo
        } else {
            fileManager.breadcrumbsFilePathOne
        }
    }

    private func switchFileHandle() {
        closeFileHandle()

        switchCurrentFilePath()

        SentrySDKLog.debug("Switching breadcrumb file handle to \(currentFilePath)")

        fileManager.removeFile(atPath: currentFilePath)

        fileHandle = fileHandleForWriting()

        if fileHandle == nil {
            SentrySDKLog.error("Couldn't open file handle for \(currentFilePath)")
        } else {
            breadcrumbCounter = 0
        }
    }

    private func deleteFiles() {
        SentrySDKLog.debug("Deleting files")

        closeFileHandle()
        breadcrumbCounter = 0

        fileManager.removeFile(atPath: fileManager.breadcrumbsFilePathOne)
        fileManager.removeFile(atPath: fileManager.breadcrumbsFilePathTwo)

        resetCurrentFilePath()
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
        }
    }

    private func fileHandleForWriting() -> FileHandle? {
        if fileHandle == nil {
            guard fileManager.write(Data(), toPath: currentFilePath) else {
                SentrySDKLog.error("Couldn't create breadcrumb file at \(currentFilePath)")
                return nil
            }

            let fileHandle = FileHandle(forWritingAtPath: currentFilePath)
            self.fileHandle = fileHandle
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
