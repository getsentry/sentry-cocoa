// swiftlint:disable missing_docs
internal import _SentryPrivate

@_spi(Private) @objc public class SentryFileManager: NSObject {

    @objc public var envelopeDeletedCallback: ((SentryEnvelopeItem, SentryDataCategory) -> Void)?

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
    
    convenience init(dateProvider: SentryCurrentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper) throws {
        let helper = try SentryFileManagerHelper(placeholder: "" as NSObject)
        self.init(helper: helper, dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
    }

    @objc public convenience init(options: Options?, dateProvider: SentryCurrentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper) throws {
        let helper = try SentryFileManagerHelper(options: options)
        self.init(helper: helper, dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
    }
        
    init(helper: SentryFileManagerHelper, dateProvider: SentryCurrentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper) {
        dispatchQueue = dispatchQueueWrapper
        self.dateProvider = dateProvider
        self.helper = helper
        super.init()

        helper.handleEnvelopesLimit = { [weak self] in
            self?.handleEnvelopesLimit()
        }
    }

    @discardableResult @objc(storeEnvelope:) public func store(_ envelope: SentryEnvelope) -> String? {
        helper.storeEnvelope(withCurrentTime: dateProvider.date().timeIntervalSince1970) { [weak self] path in
            self?.write(envelope, toPath: path) ?? false
        }
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
        helper.storeCurrentSessionData(SentrySerializationSwift.data(withJSONObject: session.serialize()))
    }
    
    @objc public func readCurrentSession() -> SentrySession? {
        helper.readCurrentSession().flatMap { SentrySerializationSwift.session(with: $0) }
    }
    
    @objc public func deleteCurrentSession() {
        helper.deleteCurrentSession()
    }
    
    @objc public func storeCrashedSession(_ session: SentrySession) {
        helper.storeCrashedSessionData(SentrySerializationSwift.data(withJSONObject: session.serialize()))
    }

    @objc public func readCrashedSession() -> SentrySession? {
        helper.readCrashedSession().flatMap { SentrySerializationSwift.session(with: $0) }
    }
    
    @objc public func deleteCrashedSession() {
        helper.deleteCrashedSession()
    }

    @objc public func storeAbnormalSession(_ session: SentrySession) {
        helper.storeAbnormalSessionData(SentrySerializationSwift.data(withJSONObject: session.serialize()))
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
        guard let data = SentrySerializationSwift.data(withJSONObject: appState.serialize()) else {
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
    
    var appHangEventFilePath: String {
        helper.appHangEventFilePath
    }

    var appStateFilePath: String {
        helper.appStateFilePath
    }

    func clearDiskState() {
        helper.clearDiskState()
    }
    
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
        let envelopeFilePaths = allFilesInFolder(envelopesPath)
        let numberOfEnvelopesToRemove = envelopeFilePaths.count - Int(helper.maxEnvelopes)
        if numberOfEnvelopesToRemove <= 0 {
            return
        }
        
        for i in 0..<numberOfEnvelopesToRemove {
            let envelopeFilePath = (envelopesPath as NSString).appendingPathComponent(envelopeFilePaths[i])
            var envelopePathsCopy = Array(envelopeFilePaths)
            envelopePathsCopy.remove(at: i)
            
            let envelopeData = FileManager.default.contents(atPath: envelopeFilePath)
            let envelope = SentrySerializationSwift.envelope(with: envelopeData ?? Data())
            let didMigrateSessionInit: Bool
            if let envelope {
                didMigrateSessionInit = SentryMigrateSessionInit.migrateSessionInit(envelope: envelope, envelopesDirPath: envelopesPath, envelopeFilePaths: envelopePathsCopy)
            } else {
                didMigrateSessionInit = false
            }
            
            for item in envelope?.items ?? [] {
                let rateLimitCategory = SentryDataCategory(itemType: item.header.type)
                // When migrating the session init, the envelope to delete still contains the session
                // migrated to another envelope. Therefore, the envelope item is not deleted but
                // migrated.
                
                if didMigrateSessionInit && rateLimitCategory == SentryDataCategory.session {
                    continue
                }
                
                envelopeDeletedCallback?(item, rateLimitCategory)
            }
            removeFile(atPath: envelopeFilePath)
        }
        SentrySDKLog.debug("Removed \(numberOfEnvelopesToRemove) file(s) from <\((envelopesPath as NSString).lastPathComponent)>")
    }
}

private extension SentryFileManager {
    func write(_ envelope: SentryEnvelope, toPath path: String) -> Bool {
        let temporaryPath = (sentryPath as NSString).appendingPathComponent("\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporaryPath, contents: nil) else {
            SentrySDKLog.error("Failed to create temporary envelope file at path: \(temporaryPath)")
            return false
        }

        guard let fileHandle = FileHandle(forWritingAtPath: temporaryPath) else {
            SentrySDKLog.error("Failed to open temporary envelope file at path: \(temporaryPath)")
            removeFile(atPath: temporaryPath)
            return false
        }

        var isFileOpen = true
        defer {
            if isFileOpen {
                try? fileHandle.close()
            }
            try? FileManager.default.removeItem(atPath: temporaryPath)
        }

        let serialized = SentrySerializationSwift.writeEnvelopeData(envelope) { data in
            do {
                try fileHandle.write(contentsOf: data)
                return true
            } catch {
                SentrySDKLog.error("Failed to write envelope data to temporary file: \(error)")
                return false
            }
        }
        guard serialized else {
            SentrySDKLog.error("Serialization of envelope failed. Can't store envelope.")
            return false
        }

        do {
            try fileHandle.synchronize()
            try fileHandle.close()
            isFileOpen = false
            try FileManager.default.moveItem(atPath: temporaryPath, toPath: path)
            return true
        } catch {
            SentrySDKLog.error("Failed to atomically store envelope at path \(path): \(error)")
            return false
        }
    }
}
// swiftlint:enable missing_docs
