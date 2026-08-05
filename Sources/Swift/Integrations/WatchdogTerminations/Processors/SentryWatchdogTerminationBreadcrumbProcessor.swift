// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryWatchdogTerminationBreadcrumbProcessor: AnyObject {
    func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any])
    func clear()
    func clearBreadcrumbs()
}

extension SentryDefaultWatchdogTerminationBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor {}
#else
typealias SentryWatchdogTerminationBreadcrumbProcessor = SentryDefaultWatchdogTerminationBreadcrumbProcessor
#endif

final class SentryDefaultWatchdogTerminationBreadcrumbProcessor: NSObject {
    private let fileManager: SentryFileManager?
    @objc private var fileHandle: FileHandle?
    private var activeFilePath: String?
    private let maxBreadcrumbs: Int
    private var breadcrumbCounter = 0

    convenience init(maxBreadcrumbs: Int) {
        self.init(
            maxBreadcrumbs: maxBreadcrumbs,
            fileManager: SentryDependencyContainer.sharedInstance().fileManager
        )
    }

    init(maxBreadcrumbs: Int, fileManager: SentryFileManager?) {
        self.maxBreadcrumbs = maxBreadcrumbs
        self.fileManager = fileManager
        super.init()

        switchFileHandle()
    }

    deinit {
        fileHandle?.closeFile()
    }

    func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any]) {
        SentrySDKLog.debug("Adding breadcrumb: \(crumb)")

        guard let jsonData = SentrySerializationSwift.data(withJSONObject: crumb) else {
            SentrySDKLog.error("Error serializing breadcrumb to JSON")
            return
        }

        storeBreadcrumb(jsonData)
    }

    func clear() {
        clearBreadcrumbs()
    }

    func clearBreadcrumbs() {
        deleteFiles()
        switchFileHandle()
    }

    private func switchFileHandle() {
        guard let fileManager else {
            SentrySDKLog.error("Cannot switch breadcrumb file handle because the file manager is nil")
            return
        }

        if activeFilePath == fileManager.breadcrumbsFilePathOne {
            activeFilePath = fileManager.breadcrumbsFilePathTwo
        } else {
            activeFilePath = fileManager.breadcrumbsFilePathOne
        }

        fileHandle?.closeFile()

        guard let activeFilePath else {
            SentrySDKLog.error("Cannot switch breadcrumb file handle because the active file path is nil")
            return
        }

        fileManager.removeFile(atPath: activeFilePath)
        FileManager.default.createFile(atPath: activeFilePath, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: activeFilePath)

        if fileHandle == nil {
            SentrySDKLog.error("Couldn't open file handle for \(activeFilePath)")
        }
    }

    private func deleteFiles() {
        fileHandle?.closeFile()
        fileHandle = nil
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
        var fileSize: UInt64 = 0

        do {
            fileSize = try fileHandle?.seekToEnd() ?? 0
            try fileHandle?.write(contentsOf: data)
            try fileHandle?.write(contentsOf: Data("\n".utf8))

            breadcrumbCounter += 1
        } catch {
            SentrySDKLog.error("Error while writing data to end file with size (\(fileSize)): \(error)")
        }

        if breadcrumbCounter >= maxBreadcrumbs {
            switchFileHandle()
            breadcrumbCounter = 0
        }
    }
}
// swiftlint:enable missing_docs
