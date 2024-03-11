import _SentryPrivate
import Nimble
import Sentry
import SentryTestUtils
import XCTest

class SentryFileManagerTests: XCTestCase {
    
    private class Fixture {
        
        let maxCacheItems = 30
        let eventIds: [SentryId]
        
        let currentDateProvider: TestCurrentDateProvider!
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        
        let options: Options
        
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        let sessionEnvelope: SentryEnvelope
        
        let sessionUpdate: SentrySession
        let sessionUpdateEnvelope: SentryEnvelope
        
        let expectedSessionUpdate: SentrySession
        
        // swiftlint:disable weak_delegate
        // Swiftlint automatically changes this to a weak reference,
        // but we need a strong reference to make the test work.
        var delegate: TestFileManagerDelegate!
        // swiftlint:enable weak_delegate
        
        init() {
            currentDateProvider = TestCurrentDateProvider()
            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            
            eventIds = (0...(maxCacheItems + 10)).map { _ in SentryId() }
            
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentryFileManagerTests")
            
            sessionEnvelope = SentryEnvelope(session: session)
            
            let sessionCopy = session.copy() as! SentrySession
            sessionCopy.incrementErrors()
            // We need to serialize in order to set the timestamp and the duration
            sessionUpdate = SentrySession(jsonObject: sessionCopy.serialize())!
            
            let event = Event()
            let items = [SentryEnvelopeItem(session: sessionUpdate), SentryEnvelopeItem(event: event)]
            sessionUpdateEnvelope = SentryEnvelope(id: event.eventId, items: items)
            
            let sessionUpdateCopy = sessionUpdate.copy() as! SentrySession
            // We need to serialize in order to set the timestamp and the duration
            expectedSessionUpdate = SentrySession(jsonObject: sessionUpdateCopy.serialize())!
            // We can only set the init flag after serialize, because the duration is not set if the init flag is set
            expectedSessionUpdate.setFlagInit()
            
            delegate = TestFileManagerDelegate()
        }
        
        func getSut() -> SentryFileManager {
            let sut = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueueWrapper)
            sut.setDelegate(delegate)
            return sut
        }
        
        func getSut(maxCacheItems: UInt) -> SentryFileManager {
            options.maxCacheItems = maxCacheItems
            let sut = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueueWrapper)
            sut.setDelegate(delegate)
            return sut
        }
        
    }
    
    private var fixture: Fixture!
    private var sut: SentryFileManager!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.currentDateProvider
        
        sut = fixture.getSut()
        
        sut.deleteAllEnvelopes()
        sut.deleteTimestampLastInForeground()
    }
    
    override func tearDown() {
        super.tearDown()
        setImmutableForAppState(immutable: false)
        setImmutableForTimezoneOffset(immutable: false)
        sut.deleteAllEnvelopes()
        sut.deleteAllFolders()
        sut.deleteTimestampLastInForeground()
        sut.deleteAppState()
        clearTestState()
    }
    
    func testInitDoesNotOverrideDirectories() {
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
        sut.storeTimestampLast(inForeground: Date())
        
        _ = try! SentryFileManager(options: fixture.options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let fileManager = try! SentryFileManager(options: fixture.options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        
        XCTAssertEqual(1, fileManager.getAllEnvelopes().count)
        XCTAssertNotNil(fileManager.readCurrentSession())
        XCTAssertNotNil(fileManager.readTimestampLastInForeground())
    }
    
    func testInitDeletesEventsFolder() {
        storeEvent()
        
        _ = try! SentryFileManager(options: fixture.options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        
        assertEventFolderDoesntExist()
    }
    
    func testInitDoesntCreateEventsFolder() {
        assertEventFolderDoesntExist()
    }
    
    func testStoreEnvelope() throws {
        let envelope = TestConstants.envelope
        sut.store(envelope)
        
        let expectedData = try SentrySerialization.data(with: envelope)
        
        let envelopes = sut.getAllEnvelopes()
        XCTAssertEqual(1, envelopes.count)
        
        let actualData = envelopes[0].contents
        XCTAssertEqual(expectedData, actualData as Data)
    }
    
    func testDeleteOldEnvelopes() throws {
        try givenOldEnvelopes()
        
        sut = fixture.getSut()
        sut.deleteOldEnvelopeItems()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 0)
    }
    
    func testDeleteOldEnvelopes_LogsIgnoreDSStoreFiles() throws {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .debug)
        
        let dsStoreFile = "\(sut.basePath)/.DS_Store"
        
        let result = FileManager.default.createFile(atPath: dsStoreFile, contents: "some data".data(using: .utf8))
        expect(result) == true
        
        sut.deleteOldEnvelopeItems()
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [debug]") &&
            $0.contains("Ignoring .DS_Store file when building envelopes path at path: \(dsStoreFile)")
        }
        expect(logMessages.count) == 1
        
        try FileManager.default.removeItem(atPath: dsStoreFile)
    }
    
    func testDeleteOldEnvelopes_LogsDebugForTextFiles() throws {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .debug)
        
        let sut = fixture.getSut()
        
        let textFilePath = "\(sut.basePath)/something.txt"
        
        let result = FileManager.default.createFile(atPath: textFilePath, contents: "some data".data(using: .utf8))
        expect(result) == true
        
        sut.deleteOldEnvelopeItems()
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [debug]") &&
            $0.contains("Ignoring non directory when deleting old envelopes at path: \(textFilePath)")
        }
        expect(logMessages.count) == 1
        
        try FileManager.default.removeItem(atPath: textFilePath)
    }
    
    func testGetEnvelopesPath_ForNonExistentPath_LogsWarning() throws {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .debug)
        
        let sut = fixture.getSut()
        
        let nonExistentFile = "nonExistentFile.txt"
        let nonExistentFileFullPath = "\(sut.basePath)/\(nonExistentFile)"
        
        expect(sut.getEnvelopesPath(nonExistentFile)) == nil
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [warning]") &&
            $0.contains("Could not get attributes of item at path: \(nonExistentFileFullPath)")
        }
        expect(logMessages.count) == 1
    }
    
    func testDeleteOldEnvelopes_WithEmptyDSN() throws {
        fixture.options.dsn = nil
        sut = fixture.getSut()
        sut.deleteOldEnvelopeItems()
        
        try givenOldEnvelopes()
        
        sut.deleteOldEnvelopeItems()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 0)
    }
    
    func testDontDeleteYoungEnvelopes() throws {
        let envelope = TestConstants.envelope
        let path = sut.store(envelope)
        
        let timeIntervalSince1970 = fixture.currentDateProvider.date().timeIntervalSince1970 - (90 * 24 * 60 * 60)
        let date = Date(timeIntervalSince1970: timeIntervalSince1970)
        try FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: path)
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
        
        sut = fixture.getSut()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
    }
    
    func testDontDeleteYoungEnvelopesFromOldEnvelopesFolder() throws {
        let envelope = TestConstants.envelope
        sut.store(envelope)
        
        let timeIntervalSince1970 = fixture.currentDateProvider.date().timeIntervalSince1970 - (90 * 24 * 60 * 60)
        let date = Date(timeIntervalSince1970: timeIntervalSince1970)
        try FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: sut.envelopesPath)
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
        
        sut = fixture.getSut()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
    }
    
    func testFileManagerDeallocated_OldEnvelopesNotDeleted() throws {
        try givenOldEnvelopes()
        
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        
        // Initialize sut in extra function so ARC deallocates it
        func getSut() {
            _ = fixture.getSut()
        }
        getSut()
        
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
    }
    
    func testCreateDirDoesNotThrow() throws {
        try SentryFileManager.createDirectory(atPath: "a")
    }
    
    func testDeleteFileNotExists() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        sut.removeFile(atPath: "x")
        XCTAssertFalse(logOutput.loggedMessages.contains(where: { $0.contains("[error]") }))
    }
    
    func testDefaultMaxEnvelopes() {
        for _ in 0...(fixture.maxCacheItems + 1) {
            sut.store(TestConstants.envelope)
        }
        
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(fixture.maxCacheItems, events.count)
    }
    
    func testDefaultMaxEnvelopes_CallsEnvelopeItemDeleted() {
        let event = Event()
        let envelope = SentryEnvelope(id: event.eventId, items: [
            SentryEnvelopeItem(event: event),
            SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024)!
        ])
        sut.store(envelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0..<(fixture.maxCacheItems) {
            sut.store(TestConstants.envelope)
        }
        
        XCTAssertEqual(4, fixture.delegate.envelopeItemsDeleted.count)
        let expected: [SentryDataCategory] = [.error, .attachment, .session, .error]
        XCTAssertEqual(expected, fixture.delegate.envelopeItemsDeleted.invocations)
    }
    
    func testDefaultMaxEnvelopesConcurrent() {
        let maxCacheItems = 1
        let sut = fixture.getSut(maxCacheItems: UInt(maxCacheItems))
        
        let parallelTaskAmount = 5
        let queue = DispatchQueue(label: "testDefaultMaxEnvelopesConcurrent", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])
        
        let envelopeStoredExpectation = expectation(description: "Envelope stored")
        envelopeStoredExpectation.expectedFulfillmentCount = parallelTaskAmount
        for _ in 0..<parallelTaskAmount {
            queue.async {
                for _ in 0...(maxCacheItems + 5) {
                    sut.store(TestConstants.envelope)
                }
                envelopeStoredExpectation.fulfill()
            }
        }
        queue.activate()
        
        wait(for: [envelopeStoredExpectation], timeout: 10)
        
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(maxCacheItems, events.count)
    }
    
    func testMaxEnvelopesSet() {
        let maxCacheItems: UInt = 15
        sut = fixture.getSut(maxCacheItems: maxCacheItems)
        for _ in 0...maxCacheItems {
            sut.store(TestConstants.envelope)
        }
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(maxCacheItems, UInt(events.count))
    }
    
    func testMigrateSessionInit_SessionUpdateIsLast() {
        sut.store(fixture.sessionEnvelope)
        // just some other session
        sut.store(SentryEnvelope(session: SentrySession(releaseName: "1.0.0", distinctId: "some-id")))
        for _ in 0...(fixture.maxCacheItems - 3) {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        
        assertSessionInitMoved(sut.getAllEnvelopes().last!)
        assertSessionEnvelopesStored(count: 2)
    }
    
    func testMigrateSessionInit_SessionUpdateIsSecond() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...(fixture.maxCacheItems - 2) {
            sut.store(TestConstants.envelope)
        }
        
        assertSessionInitMoved(sut.getAllEnvelopes().first!)
        assertSessionEnvelopesStored(count: 1)
    }
    
    func testMigrateSessionInit_IsInMiddle() {
        sut.store(fixture.sessionEnvelope)
        for _ in 0...10 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...18 {
            sut.store(TestConstants.envelope)
        }
        
        assertSessionInitMoved(sut.getAllEnvelopes()[10])
        assertSessionEnvelopesStored(count: 1)
    }
    
    func testMigrateSessionInit_MovesInitFlagOnlyToFirstSessionUpdate() {
        sut.store(fixture.sessionEnvelope)
        for _ in 0...10 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...16 {
            sut.store(TestConstants.envelope)
        }
        
        assertSessionInitMoved(sut.getAllEnvelopes()[10])
        assertSessionInitNotMoved(sut.getAllEnvelopes()[11])
        assertSessionInitNotMoved(sut.getAllEnvelopes()[12])
        assertSessionEnvelopesStored(count: 3)
    }
    
    func testMigrateSessionInit_NoOtherSessionUpdate() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...(fixture.maxCacheItems - 1) {
            sut.store(TestConstants.envelope)
        }
        
        assertSessionEnvelopesStored(count: 0)
    }
    
    func testMigrateSessionInit_FailToLoadEnvelope() {
        sut.store(fixture.sessionEnvelope)
        
        for _ in 0...(fixture.maxCacheItems - 3) {
            sut.store(TestConstants.envelope)
        }
        
        // Trying to load the file content of a directory is going to return nil for the envelope.
        let envelopePath = sut.store(TestConstants.envelope)
        let fileManager = FileManager.default
        try! fileManager.removeItem(atPath: envelopePath)
        try! fileManager.createDirectory(atPath: envelopePath, withIntermediateDirectories: false, attributes: nil)
        
        sut.store(fixture.sessionUpdateEnvelope)
        
        assertSessionInitMoved(sut.getAllEnvelopes().last!)
    }
    
    func testMigrateSessionInit_DoesNotCallEnvelopeItemDeleted() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...(fixture.maxCacheItems - 2) {
            sut.store(TestConstants.envelope)
        }
        
        XCTAssertEqual(0, fixture.delegate.envelopeItemsDeleted.count)
    }
    
    func testGetAllEnvelopesAreSortedByDateAscending() {
        givenMaximumEnvelopes()
        
        let envelopes = sut.getAllEnvelopes()
        
        // Envelopes are sorted ascending by date and only the latest amount of maxCacheItems are kept
        let expectedEventIds = Array(fixture.eventIds[11..<fixture.eventIds.count])
        
        XCTAssertEqual(fixture.maxCacheItems, envelopes.count)
        for i in 0..<fixture.maxCacheItems {
            let envelope = SentrySerialization.envelope(with: envelopes[i].contents)
            let actualEventId = envelope?.header.eventId
            XCTAssertEqual(expectedEventIds[i], actualEventId)
        }
    }
    
    func testGetOldestEnvelope() {
        givenMaximumEnvelopes()
        
        let actualEnvelope = SentrySerialization.envelope(with: sut.getOldestEnvelope()?.contents ?? Data())
        
        XCTAssertEqual(fixture.eventIds[11], actualEnvelope?.header.eventId)
    }
    
    func testGetOldestEnvelope_WhenNoEnvelopes() {
        XCTAssertNil(sut.getOldestEnvelope())
    }
    
    func testGetOldestEnvelope_WithGarbageInEnvelopesFolder() {
        givenGarbageInEnvelopesFolder()
        
        let actualEnvelope = SentrySerialization.envelope(with: sut.getOldestEnvelope()?.contents ?? Data())
        XCTAssertNil(actualEnvelope)
    }
    
    func testStoreAndReadCurrentSession() {
        let expectedSession = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        sut.storeCurrentSession(expectedSession)
        let actualSession = sut.readCurrentSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
        XCTAssertNil(sut.readCrashedSession())
    }
    
    func testStoreAndReadCrashedSession() {
        let expectedSession = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        sut.storeCrashedSession(expectedSession)
        let actualSession = sut.readCrashedSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
    }
    
    func testStoreDeleteCurrentSession() {
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
        sut.deleteCurrentSession()
        let actualSession = sut.readCurrentSession()
        XCTAssertNil(actualSession)
    }
    
    func testStoreDeleteCrashedSession() {
        sut.storeCrashedSession(SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
        sut.deleteCrashedSession()
        let actualSession = sut.readCrashedSession()
        XCTAssertNil(actualSession)
    }
    
    func testStoreAndReadTimestampLastInForeground() {
        let expectedTimestamp = TestCurrentDateProvider().date()
        sut.storeTimestampLast(inForeground: expectedTimestamp)
        let actualTimestamp = sut.readTimestampLastInForeground()
        XCTAssertEqual(actualTimestamp, expectedTimestamp)
    }
    
    func testStoreDeleteTimestampLastInForeground() {
        sut.storeTimestampLast(inForeground: Date())
        sut.deleteTimestampLastInForeground()
        let actualTimestamp = sut.readTimestampLastInForeground()
        XCTAssertNil(actualTimestamp)
    }
    
    func testGetAllStoredEventsAndEnvelopes() {
        sut.store(TestConstants.envelope)
        sut.store(TestConstants.envelope)
        
        XCTAssertEqual(2, sut.getAllEnvelopes().count)
    }
    
    func testDeleteAllFolders() {
        storeEvent()
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.1", distinctId: "some-id"))
        
        sut.deleteAllFolders()
        
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        XCTAssertNil(sut.readCurrentSession())
        assertEventFolderDoesntExist()
    }
    
    func testDeleteAllStoredEnvelopes() {
        sut.store(TestConstants.envelope)
        
        sut.deleteAllEnvelopes()
        
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
    }
    
    func testGetAllEnvelopesWhenNoEnvelopesPath_LogsInfoMessage() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .debug)
        
        sut.deleteAllFolders()
        sut.getAllEnvelopes()
        
        let debugLogMessages = logOutput.loggedMessages.filter { $0.contains("[Sentry] [info]") && $0.contains("Returning empty files list, as folder doesn't exist at path:") }
        expect(debugLogMessages.count) == 1
        
        let errorMessages = logOutput.loggedMessages.filter { $0.contains("[Sentry] [error]") }
        
        expect(errorMessages.count) == 0
    }
    
    func testReadStoreDeleteAppState() {
        sut.store(TestData.appState)
        
        assertValidAppStateStored()
        
        sut.deleteAppState()
        XCTAssertNil(sut.readAppState())
    }
    
    func testDeletePreviousAppState() {
        sut.store(TestData.appState)
        sut.moveAppStateToPreviousAppState()
        sut.deleteAppState()
        
        XCTAssertNil(sut.readAppState())
        XCTAssertNil(sut.readPreviousAppState())
    }
    
    func testStore_WhenFileImmutable_AppStateIsNotOverwritten() {
        sut.store(TestData.appState)
        
        setImmutableForAppState(immutable: true)
        
        sut.store(SentryAppState(releaseName: "", osVersion: "", vendorId: "", isDebugging: false, systemBootTimestamp: fixture.currentDateProvider.date()))
        
        assertValidAppStateStored()
    }
    
    func testStoreFaultyAppState_AppStateIsNotOverwritten() {
        sut.store(TestData.appState)
        
        sut.store(AppStateWithFaultySerialization(releaseName: "", osVersion: "", vendorId: "", isDebugging: false, systemBootTimestamp: fixture.currentDateProvider.date()))
        
        assertValidAppStateStored()
    }
    
    func testReadWhenNoAppState_ReturnsNil() {
        XCTAssertNil(sut.readAppState())
    }
    
    func testDeleteAppState_WhenFileLocked_DontCrash() throws {
        sut.store(TestData.appState)
        
        setImmutableForAppState(immutable: true)
        
        sut.deleteAppState()
        XCTAssertNotNil(sut.readAppState())
    }
    
    func testMoveAppStateAndReadPreviousAppState() {
        sut.store(TestData.appState)
        sut.moveAppStateToPreviousAppState()
        
        let actual = sut.readPreviousAppState()
        XCTAssertEqual(TestData.appState, actual)
    }
    
    func testMoveAppStateWhenPreviousAppStateAlreadyExists() {
        sut.store(TestData.appState)
        sut.moveAppStateToPreviousAppState()
        
        let newAppState = SentryAppState(releaseName: "2.0.0", osVersion: "14.4.1", vendorId: "12345678-1234-1234-1234-12344567890AB", isDebugging: false, systemBootTimestamp: Date(timeIntervalSince1970: 10))
        sut.store(newAppState)
        sut.moveAppStateToPreviousAppState()
        
        let actual = sut.readPreviousAppState()
        XCTAssertEqual(newAppState, actual)
    }
    
    func testStoreAndReadTimezoneOffset() {
        sut.storeTimezoneOffset(7_200)
        XCTAssertEqual(sut.readTimezoneOffset(), 7_200)
    }
    
    func testtestStoreAndReadNegativeTimezoneOffset() {
        sut.storeTimezoneOffset(-1_000)
        XCTAssertEqual(sut.readTimezoneOffset(), -1_000)
    }
    
    func testStoreDeleteTimezoneOffset() {
        sut.storeTimezoneOffset(7_200)
        sut.deleteTimezoneOffset()
        XCTAssertNil(sut.readTimezoneOffset())
    }
    
    func testStore_WhenFileImmutable_TimezoneOffsetIsNotOverwritten() {
        sut.storeTimezoneOffset(7_200)
        
        setImmutableForTimezoneOffset(immutable: true)
        
        sut.storeTimezoneOffset(9_600)
        
        XCTAssertEqual(sut.readTimezoneOffset(), 7_200)
    }
    
    func testStoreDeleteTimezoneOffset_WhenFileLocked_DontCrash() throws {
        sut.storeTimezoneOffset(7_200)
        
        setImmutableForTimezoneOffset(immutable: true)
        
        sut.deleteTimezoneOffset()
        XCTAssertNotNil(sut.readTimezoneOffset())
    }
    
    func testSentryPathFromOptionsCacheDirectoryPath() {
        fixture.options.cacheDirectoryPath = "/var/tmp"
        sut = fixture.getSut()
        
        XCTAssertTrue(sut.sentryPath.hasPrefix("/var/tmp/io.sentry"))
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testReadPreviousBreadcrumbs() {
        let observer = SentryWatchdogTerminationScopeObserver(maxBreadcrumbs: 2, fileManager: sut)
        
        for count in 0..<3 {
            let crumb = TestData.crumb
            crumb.message = "\(count)"
            let serializedBreadcrumb = crumb.serialize()
            
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }
        
        sut.moveBreadcrumbsToPreviousBreadcrumbs()
        let result = sut.readPreviousBreadcrumbs()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual((result[0] as! NSDictionary)["message"] as! String, "0")
        XCTAssertEqual((result[1] as! NSDictionary)["message"] as! String, "1")
        XCTAssertEqual((result[2] as! NSDictionary)["message"] as! String, "2")
    }
    
    func testReadPreviousBreadcrumbsCorrectOrderWhenFileTwoHasMoreCrumbs() {
        let observer = SentryWatchdogTerminationScopeObserver(maxBreadcrumbs: 2, fileManager: sut)
        
        for count in 0..<5 {
            let crumb = TestData.crumb
            crumb.message = "\(count)"
            let serializedBreadcrumb = crumb.serialize()
            
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }
        
        sut.moveBreadcrumbsToPreviousBreadcrumbs()
        let result = sut.readPreviousBreadcrumbs()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual((result[0] as! NSDictionary)["message"] as! String, "2")
        XCTAssertEqual((result[1] as! NSDictionary)["message"] as! String, "3")
        XCTAssertEqual((result[2] as! NSDictionary)["message"] as! String, "4")
    }
    
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testReadGarbageTimezoneOffset() throws {
        try "garbage".write(to: URL(fileURLWithPath: sut.timezoneOffsetFilePath), atomically: true, encoding: .utf8)
        XCTAssertNil(sut.readTimezoneOffset())
    }
}

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
// MARK: App Launch profiling tests
extension SentryFileManagerTests {
    // if app launch profiling was configured to take place
    func testAppLaunchProfileConfigFileExists_fileExists() throws {
        try ensureAppLaunchProfileConfig()
        expect(appLaunchProfileConfigFileExists()) == true
    }
    
    // if app launch profiling was not configured to take place
    func testAppLaunchProfileConfigFileExists_fileDoesNotExist() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        expect(appLaunchProfileConfigFileExists()) == false
    }
    
    func testAppLaunchProfileConfiguration() throws {
        let expectedTracesSampleRate = 0.12
        let expectedProfilesSampleRate = 0.34
        try ensureAppLaunchProfileConfig(tracesSampleRate: expectedTracesSampleRate, profilesSampleRate: expectedProfilesSampleRate)
        let config = appLaunchProfileConfiguration()
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate]).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate]).doubleValue
        expect(actualTracesSampleRate) == expectedTracesSampleRate
        expect(actualProfilesSampleRate) == expectedProfilesSampleRate
    }
    
    // if a file isn't present when we expect it to be, like if there was an issue when we went to write it to disk
    func testAppLaunchProfileConfiguration_noConfigurationExists() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        expect(appLaunchProfileConfiguration()) == nil
    }
    
    func testWriteAppLaunchProfilingConfigFile_noCurrentFileExists() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        
        let expectedTracesSampleRate = 0.12
        let expectedProfilesSampleRate = 0.34
        writeAppLaunchProfilingConfigFile([
            kSentryLaunchProfileConfigKeyTracesSampleRate: expectedTracesSampleRate,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: expectedProfilesSampleRate
        ])
        
        let config = NSDictionary(contentsOf: launchProfileConfigFileURL())
        
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate] as? NSNumber).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate] as? NSNumber).doubleValue
        expect(actualTracesSampleRate) == expectedTracesSampleRate
        expect(actualProfilesSampleRate) == expectedProfilesSampleRate
    }
    
    // if a file is still present in the primary location, like if a crash occurred before it could be removed, or an error occurred when trying to remove it or move it to the backup location, make sure we overwrite it
    func testWriteAppLaunchProfilingConfigFile_fileAlreadyExists() throws {
        try ensureAppLaunchProfileConfig(exists: true, tracesSampleRate: 0.75, profilesSampleRate: 0.75)
        
        let expectedTracesSampleRate = 0.12
        let expectedProfilesSampleRate = 0.34
        writeAppLaunchProfilingConfigFile([
            kSentryLaunchProfileConfigKeyTracesSampleRate: expectedTracesSampleRate,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: expectedProfilesSampleRate
        ])
        
        let config = NSDictionary(contentsOf: launchProfileConfigFileURL())
        
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate] as? NSNumber).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate] as? NSNumber).doubleValue
        expect(actualTracesSampleRate) == expectedTracesSampleRate
        expect(actualProfilesSampleRate) == expectedProfilesSampleRate
    }
    
    func testRemoveAppLaunchProfilingConfigFile() throws {
        try ensureAppLaunchProfileConfig(exists: true)
        expect(NSDictionary(contentsOf: launchProfileConfigFileURL())) != nil
        removeAppLaunchProfilingConfigFile()
        expect(NSDictionary(contentsOf: launchProfileConfigFileURL())) == nil
    }
    
    // if there's not a file when we expect one, just make sure we don't crash
    func testRemoveAppLaunchProfilingConfigFile_noFileExists() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        expect(NSDictionary(contentsOf: launchProfileConfigFileURL())) == nil
        removeAppLaunchProfilingConfigFile()
        expect(NSDictionary(contentsOf: launchProfileConfigFileURL())) == nil
    }
    
    func testCheckForLaunchProfilingConfigFile_URLDoesNotExist() {
        // cause the dispatch_once to initialize the internal value
        let originalURL = launchProfileConfigFileURL()

        // set to nil to simulate exceptional environments
        sentryLaunchConfigFileURL = nil

        // make sure we return a default-off value and also don't crash the call to access()
        expect(appLaunchProfileConfigFileExists()) == false
        
        // set the original value back so other tests don't crash
        sentryLaunchConfigFileURL = (originalURL as NSURL)
    }
}

// MARK: Private profiling tests
private extension SentryFileManagerTests {
    func ensureAppLaunchProfileConfig(exists: Bool = true, tracesSampleRate: Double = 1, profilesSampleRate: Double = 1) throws {
        let url = launchProfileConfigFileURL()
        
        if exists {
            let dict = [kSentryLaunchProfileConfigKeyTracesSampleRate: tracesSampleRate, kSentryLaunchProfileConfigKeyProfilesSampleRate: profilesSampleRate]
            try (dict as NSDictionary).write(to: url)
        } else {
            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

// MARK: Private
private extension SentryFileManagerTests {
    func givenMaximumEnvelopes() {
        fixture.eventIds.forEach { id in
            let envelope = SentryEnvelope(id: id, singleItem: SentryEnvelopeItem(event: Event()))

            sut.store(envelope)
            advanceTime(bySeconds: 0.1)
        }
    }

    func givenGarbageInEnvelopesFolder() {
        do {
            try "garbage".write(to: URL(fileURLWithPath: "\(sut.envelopesPath)/garbage.json"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to store garbage in Envelopes folder.")
        }
    }
    
    func givenOldEnvelopes() throws {
        let envelope = TestConstants.envelope
        let path = sut.store(envelope)

        let timeIntervalSince1970 = fixture.currentDateProvider.date().timeIntervalSince1970 - (90 * 24 * 60 * 60)
        let date = Date(timeIntervalSince1970: timeIntervalSince1970 - 1)
        try FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: path)

        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
    }

    func storeEvent() {
        do {
            // Store a fake event to the events folder
            try FileManager.default.createDirectory(atPath: sut.eventsPath, withIntermediateDirectories: true, attributes: nil)
            try "fake event".write(to: URL(fileURLWithPath: "\(sut.eventsPath)/event.json"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to store fake event.")
        }
    }
    
    func setImmutableForAppState(immutable: Bool) {
        let appStateFilePath = Dynamic(sut).appStateFilePath.asString ?? ""
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: appStateFilePath) {
            return
        }
        
        do {
            try fileManager.setAttributes([FileAttributeKey.immutable: immutable], ofItemAtPath: appStateFilePath)
        } catch {
            XCTFail("Couldn't change immutable state of app state file.")
        }
    }

    func setImmutableForTimezoneOffset(immutable: Bool) {
        let timezoneOffsetFilePath = Dynamic(sut).timezoneOffsetFilePath.asString ?? ""
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: timezoneOffsetFilePath) {
            return
        }

        do {
            try fileManager.setAttributes([FileAttributeKey.immutable: immutable], ofItemAtPath: timezoneOffsetFilePath)
        } catch {
            XCTFail("Couldn't change immutable state of timezone offset file.")
        }
    }

    func assertEventFolderDoesntExist() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: sut.eventsPath),
                        "Folder for events should be deleted on init: \(sut.eventsPath)")
    }

    func assertSessionInitMoved(_ actualSessionFileContents: SentryFileContents) {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: actualSessionEnvelope?.items[1].data ?? Data())
        XCTAssertNotNil(actualSession)

        XCTAssertEqual(fixture.expectedSessionUpdate, actualSession)
    }
    
    func assertSessionInitNotMoved(_ actualSessionFileContents: SentryFileContents) {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: actualSessionEnvelope?.items[0].data ?? Data())
        XCTAssertNotNil(actualSession)

        XCTAssertEqual(fixture.sessionUpdate, actualSession)
    }

    func assertSessionEnvelopesStored(count: Int) {
        let fileContentsWithSession = sut.getAllEnvelopes().filter { envelopeFileContents in
            let envelope = SentrySerialization.envelope(with: envelopeFileContents.contents)
            return !(envelope?.items.filter { item in item.header.type == SentryEnvelopeItemTypeSession }.isEmpty ?? false)
        }

        XCTAssertEqual(count, fileContentsWithSession.count)
    }
    
    func assertValidAppStateStored() {
        let actual = sut.readAppState()
        XCTAssertEqual(TestData.appState, actual)
    }

    func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
    
    class AppStateWithFaultySerialization: SentryAppState {
        override func serialize() -> [String: Any] {
            return ["app": self]
        }
    }
}
