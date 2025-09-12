@_implementationOnly import _SentryPrivate

/**
 * The data category rate limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and
 * client reports: https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload. Be aware
 * that these categories are different from the envelope item types.
 */
@_spi(Private) @objc public enum SentryDataCategorySwift: Int {
    case all = 0
    case `default` = 1
    case error = 2
    case session = 3
    case transaction = 4
    case attachment = 5
    case userFeedback = 6
    case profile = 7
    case metricBucket = 8
    case replay = 9
    case profileChunk = 10
    case span = 11
    case feedback = 12
    case logItem = 13
    case unknown = 14
    
    //swiftlint:disable cyclomatic_complexity
    static func fromDataCategory(_ dataCategory: SentryDataCategory) -> Self {
        switch dataCategory {
        case .all:
            return .all
        case .default:
            return .default
        case .error:
            return .error
        case .session:
            return .session
        case .transaction:
            return .transaction
        case .attachment:
            return .attachment
        case .userFeedback:
            return .userFeedback
        case .profile:
            return .profile
        case .metricBucket:
            return .metricBucket
        case .replay:
            return .replay
        case .profileChunk:
            return .profileChunk
        case .span:
            return .span
        case .feedback:
            return .feedback
        case .logItem:
                return .logItem
        case .unknown:
            fallthrough
        @unknown default:
                return .unknown
        }
    }
    //swiftlint:enable cyclomatic_complexity
}

@_spi(Private) @objc public class SentryFileManager: NSObject {

    @objc public var envelopeDeletedCallback: ((SentryEnvelopeItem, SentryDataCategorySwift) -> Void)?

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
        dispatchQueue = dispatchQueueWrapper
        self.dateProvider = dateProvider
        helper = try SentryFileManagerHelper(options: options)
        super.init()

        helper.handleEnvelopesLimit = { [weak self] in
            self?.handleEnvelopesLimit()
        }
    }

    @discardableResult @objc(storeEnvelope:) public func store(_ envelope: SentryEnvelope) -> String? {
        let envelopeData = SentrySerialization.data(with: envelope)
        guard let envelopeData else {
            SentrySDKLog.error("Serialization of envelope failed. Can't store envelope.")
            return nil
        }
        return helper.storeEnvelopeData(envelopeData, currentTime: self.dateProvider.date().timeIntervalSince1970)
    }
    
    @objc public func getEnvelopesPath(_ filePath: String) -> String? {
        helper.getEnvelopesPath(filePath)
    }

    @objc public func getAllEnvelopes() -> [SentryFileContents] {
        allFilesContentInFolder(path: envelopesPath)
    }

    @objc public func getOldestEnvelope() -> SentryFileContents? {
        let pathsOfAllEnvelopes = helper.pathsOfAllEnvelopes()
        
        if let pathsOfAllEnvelopes, pathsOfAllEnvelopes.count > 0 {
            let filePath = pathsOfAllEnvelopes[0]
            return getFileContents(folderPath: envelopesPath, filePath: filePath)
        }

        return nil
    }

    @objc public func deleteOldEnvelopeItems() {
        let dateProvider = self.dateProvider
        dispatchQueue.dispatchAsync { [weak self] in
            let now = dateProvider.date().timeIntervalSince1970
            self?.helper.deleteOldEnvelopes(fromAllSentryPaths: now)
        }
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
        helper.storeCurrentSessionData(SentrySerialization.data(withJSONObject: session.serialize()))
    }
    
    @objc public func readCurrentSession() -> SentrySession? {
        helper.readCurrentSession().flatMap { SentrySerializationSwift.session(with: $0) }
    }
    
    @objc public func deleteCurrentSession() {
        helper.deleteCurrentSession()
    }
    
    @objc public func storeCrashedSession(_ session: SentrySession) {
        helper.storeCrashedSessionData(SentrySerialization.data(withJSONObject: session.serialize()))
    }

    @objc public func readCrashedSession() -> SentrySession? {
        helper.readCrashedSession().flatMap { SentrySerializationSwift.session(with: $0) }
    }
    
    @objc public func deleteCrashedSession() {
        helper.deleteCrashedSession()
    }

    @objc public func storeAbnormalSession(_ session: SentrySession) {
        helper.storeAbnormalSessionData(SentrySerialization.data(withJSONObject: session.serialize()))
    }
    
    @objc public func readAbnormalSession() -> SentrySession? {
        helper.readAbnormalSession().flatMap { SentrySerializationSwift.session(with: $0) }
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

    @objc(storeAppState:) public func store(_ appState: SentryAppState) {
        guard let data = SentrySerialization.data(withJSONObject: appState.serialize()) else {
            SentrySDKLog.error("Failed to store app state, because of an error in serialization")
            return
        }

        helper.storeAppStateData(data)
    }
    
    @objc public func moveAppStateToPreviousAppState() {
        helper.moveAppStateToPreviousAppState()
    }
    
    @objc public func readAppState() -> SentryAppState? {
        helper.readAppStateData().flatMap { SentrySerializationSwift.appState(with: $0) }
    }
    
    @objc public func readPreviousAppState() -> SentryAppState? {
        helper.readPreviousAppState().flatMap { SentrySerializationSwift.appState(with: $0) }
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

    @objc public static func createDirectory(atPath path: String) throws {
        try SentryFileManagerHelper.createDirectory(atPath: path)
    }
    
    @objc public func deleteAllFolders() {
        helper.deleteAllFolders()
    }
    
    @objc public func removeFile(atPath path: String) {
        helper.removeFile(atPath: path)
    }
    
    @objc public func allFilesInFolder(_ path: String) -> [String] {
        helper.allFiles(inFolder: path)
    }
    
    @objc public func isDirectory(_ path: String) -> Bool {
        helper.isDirectory(path)
    }
    
    @objc public func readData(fromPath path: String) throws -> Data {
        try helper.readData(fromPath: path)
    }
    
    @discardableResult @objc(writeData:toPath:) public func write(_ data: Data, toPath: String) -> Bool {
        helper.write(data, toPath: toPath)
    }
    
    // MARK: Internal
    
    #if SENTRY_TEST
    func clearDiskState() {
        helper.clearDiskState()
    }
    #endif
    
    var envelopesPath: String {
        helper.envelopesPath
    }
    
    var timezoneOffsetFilePath: String {
        helper.timezoneOffsetFilePath
    }
    
    var eventsPath: String {
        helper.eventsPath
    }
    
    // MARK: Private

    private let helper: SentryFileManagerHelper
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let dateProvider: SentryCurrentDateProvider
    
    private func allFilesContentInFolder(path: String) -> [SentryFileContents] {
        allFilesInFolder(path).compactMap { filePath in
            getFileContents(folderPath: path, filePath: filePath)
        }
    }
    
    private func getFileContents(folderPath: String, filePath: String) -> SentryFileContents? {
        let finalPath = (folderPath as NSString).appendingPathComponent(filePath)
        guard let content = FileManager.default.contents(atPath: finalPath) else {
            return nil
        }
        return SentryFileContents(path: finalPath, contents: content)
    }
    
    private func handleEnvelopesLimit() {
        let envelopeFilePaths = self.allFilesInFolder(envelopesPath)
        let numberOfEnvelopesToRemove = envelopeFilePaths.count - Int(helper.maxEnvelopes)
        if numberOfEnvelopesToRemove <= 0 {
            return
        }
        
        for (i, path) in envelopeFilePaths.enumerated() {
            let envelopeFilePath = (envelopesPath as NSString).appendingPathComponent(path)
            var envelopePathsCopy = Array(envelopeFilePaths)
            envelopePathsCopy.remove(at: i)
            
            let envelopeData = FileManager.default.contents(atPath: envelopeFilePath)
            let envelope = SentrySerializationSwift.envelope(with: envelopeData ?? Data())
            let didMigrateSessionInit: Bool
            if let envelope {
                    let envelopeItemData = envelope.items.filter { $0.header.type == SentryEnvelopeItemTypes.session }.compactMap { $0.data }
                didMigrateSessionInit = SentryMigrateSessionInit.migrateSessionInit(envelopeItemData, envelopesDirPath: envelopesPath, envelopeFilePaths: envelopePathsCopy)
            } else {
                didMigrateSessionInit = false
            }
            
            for item in envelope?.items ?? [] {
                let rateLimitCategory = sentryDataCategoryForEnvelopItemType(item.header.type)
                // When migrating the session init, the envelope to delete still contains the session
                // migrated to another envelope. Therefore, the envelope item is not deleted but
                // migrated.
                
                if didMigrateSessionInit && rateLimitCategory == SentryDataCategory.session {
                    continue
                }
                
                envelopeDeletedCallback?(item, SentryDataCategorySwift.fromDataCategory(rateLimitCategory))
            }
            removeFile(atPath: envelopeFilePath)
        }
        SentrySDKLog.debug("Removed \(numberOfEnvelopesToRemove) file(s) from <\((envelopesPath as NSString).lastPathComponent)>")
    }
}
