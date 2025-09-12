@_implementationOnly import _SentryPrivate

/**
 * The data category rate limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and
 * client reports: https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload. Be aware
 * that these categories are different from the envelope item types.
 */
@_spi(Private) @objc public enum SentryDataCategorySwift: Int {
    case kSentryDataCategoryAll = 0
    case kSentryDataCategoryDefault = 1
    case kSentryDataCategoryError = 2
    case kSentryDataCategorySession = 3
    case kSentryDataCategoryTransaction = 4
    case kSentryDataCategoryAttachment = 5
    case kSentryDataCategoryUserFeedback = 6
    case kSentryDataCategoryProfile = 7
    case kSentryDataCategoryMetricBucket = 8
    case kSentryDataCategoryReplay = 9
    case kSentryDataCategoryProfileChunk = 10
    case kSentryDataCategorySpan = 11
    case kSentryDataCategoryFeedback = 12
    case kSentryDataCategoryLogItem = 13
    case kSentryDataCategoryUnknown = 14
}

@_spi(Private) @objc public protocol SentryFileManagerDelegate {
    func envelopeItemDeleted(
        _ envelopeItem: SentryEnvelopeItem,
        withCategory dataCategory: SentryDataCategorySwift
    )
}

@_spi(Private) @objc public final class SentryFileManager: NSObject {
    
    private let helper: SentryFileManagerHelper
    
    @objc public var basePath: String {
        helper.basePath
    }
    @objc public var sentryPath: String {
        helper.sentryPath
    }

    @objc public var breadcrumbsFilePathOne: String {
        helper.breadcrumbsFilePathOne
    }
    @objc public var breadcrumbsFilePathTwo: String {
        helper.breadcrumbsFilePathTwo
    }
    @objc public var previousBreadcrumbsFilePathOne: String {
        helper.previousBreadcrumbsFilePathOne
    }
    @objc public var previousBreadcrumbsFilePathTwo: String {
        helper.previousBreadcrumbsFilePathTwo
    }

    @objc public init(options: Options, dateProvider: SentryCurrentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper) throws {
        helper = try SentryFileManagerHelper(options: options, dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
    }
    
    @objc public func setDelegate(_ delegate: SentryFileManagerDelegate) {
        // helper.setDelegate(delegate)
    }

    @discardableResult @objc(storeEnvelope:) public func store(_ envelope: SentryEnvelope) -> String? {
        helper.store(envelope)
    }
    
    @objc public func getEnvelopesPath(_ filePath: String) -> String? {
        helper.getEnvelopesPath(filePath)
    }

    @objc public func getAllEnvelopes() -> [SentryFileContents] {
        //helper.getAllEnvelopes()
        []
    }

    @objc public func getOldestEnvelope() -> SentryFileContents? {
        // helper.getOldestEnvelope()
        nil
    }

    @objc public func deleteOldEnvelopeItems() {
        helper.deleteOldEnvelopeItems()
    }
    
    @objc public func deleteAllEnvelopes() {
        helper.deleteAllEnvelopes()
    }
    
    @objc public func getSentryPathAsURL() -> URL {
        helper.getSentryPathAsURL()
    }

    @objc public func moveState(_ stateFilePath: String, toPreviousState previousStateFilePath: String) {
        helper.moveState(stateFilePath, toPreviousState: previousStateFilePath)
    }
    
    @objc public func storeCurrentSession(_ session: SentrySession) {
        // helper.storeCurrentSession(session)
    }
    
    @objc public func readCurrentSession() -> SentrySession? {
        // helper.readCurrentSession()
        nil
    }
    
    @objc public func deleteCurrentSession() {
        helper.deleteCurrentSession()
    }
    
    @objc public func storeCrashedSession(_ session: SentrySession) {
        // helper.storeCrashedSession(session)
    }

    @objc public func readCrashedSession() -> SentrySession? {
        // helper.readCrashedSession()
        nil
    }
    
    @objc public func deleteCrashedSession() {
        helper.deleteCrashedSession()
    }

    @objc public func storeAbnormalSession(_ session: SentrySession) {
        // helper.storeAbnormalSession(session)
    }
    
    @objc public func readAbnormalSession() -> SentrySession? {
        // helper.readAbnormalSession()
        nil
    }
    
    @objc public func deleteAbnormalSession() {
        helper.deleteAbnormalSession()
    }
    
    @objc public func storeTimestampLast(inForeground timestamp: Date) {
        helper.storeTimestampLast(inForeground: timestamp)
    }
    
    @objc public func readTimestampLastInForeground() -> Date? {
        helper.readTimestampLastInForeground()
    }
    
    @objc public func deleteTimestampLastInForeground() {
        helper.deleteTimestampLastInForeground()
    }

    @objc public func storeAppState(_ appState: SentryAppState) {
        // helper.storeAppState(appState)
    }
    
    @objc public func moveAppStateToPreviousAppState() {
        helper.moveAppStateToPreviousAppState()
    }
    
    @objc public func readAppState() -> SentryAppState? {
        // helper.readAppState()
        nil
    }
    
    @objc public func readPreviousAppState() -> SentryAppState? {
        // helper.readPreviousAppState()
        nil
    }
    
    @objc public func deleteAppState() {
        helper.deleteAppState()
    }

    @objc public func moveBreadcrumbsToPreviousBreadcrumbs() {
        helper.moveBreadcrumbsToPreviousBreadcrumbs()
    }
    
    @objc public func readPreviousBreadcrumbs() -> [Any] {
        helper.readPreviousBreadcrumbs()
    }
    
    @objc public func readTimezoneOffset() -> NSNumber? {
        helper.readTimezoneOffset()
    }
    
    @objc public func storeTimezoneOffset(_ offset: Int) {
        helper.storeTimezoneOffset(offset)
    }
    
    @objc public func deleteTimezoneOffset() {
        helper.deleteTimezoneOffset()
    }

    @objc(storeAppHangEvent:) public func storeAppHang(_ event: Event) {
        helper.storeAppHang(event)
    }
    
    @objc public func readAppHangEvent() -> Event? {
        helper.readAppHangEvent()
    }
    
    @objc public func appHangEventExists() -> Bool {
        helper.appHangEventExists()
    }
    
    @objc public func deleteAppHangEvent() {
        helper.deleteAppHangEvent()
    }

    @objc public static func createDirectoryAtPath(
        _ path: String,
    ) throws {
        try SentryFileManagerHelper.createDirectory(atPath: path)
    }
    
    @objc public func deleteAllFolders() {
        helper.deleteAllFolders()
    }
    
    @objc public func removeFileAtPath(_ path: String) {
        helper.removeFile(atPath: path)
    }
    
    @objc public func allFilesInFolder(_ path: String) -> [String] {
        helper.allFiles(inFolder: path)
    }
    
    @objc public func isDirectory(_ path: String) -> Bool {
        helper.isDirectory(path)
    }
    
    @objc public func readDataFromPath(_ path: String) throws -> Data {
        try helper.readData(fromPath: path)
    }
    
    @objc public func write(_ data: Data, toPath: String) -> Bool {
        helper.write(data, toPath: toPath)
    }
}
