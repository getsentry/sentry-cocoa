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

        let session = SentrySession(releaseName: "1.0.0")
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
            let sut = try! SentryFileManager(options: options, andCurrentDateProvider: currentDateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
            sut.setDelegate(delegate)
            return sut
        }
        
        func getSut(maxCacheItems: UInt) -> SentryFileManager {
            options.maxCacheItems = maxCacheItems
            let sut = try! SentryFileManager(options: options, andCurrentDateProvider: currentDateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
            sut.setDelegate(delegate)
            return sut
        }

    }

    private var fixture: Fixture!
    private var sut: SentryFileManager!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        CurrentDate.setCurrentDateProvider(fixture.currentDateProvider)

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
    }
    
    func testInitDoesNotOverrideDirectories() {
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0"))
        sut.storeTimestampLast(inForeground: Date())

        _ = try! SentryFileManager(options: fixture.options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        let fileManager = try! SentryFileManager(options: fixture.options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        XCTAssertEqual(1, fileManager.getAllEnvelopes().count)
        XCTAssertNotNil(fileManager.readCurrentSession())
        XCTAssertNotNil(fileManager.readTimestampLastInForeground())
    }
    
    func testInitDeletesEventsFolder() {
        storeEvent()
        
        _ = try! SentryFileManager(options: fixture.options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        
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
    
    func testAllFilesInFolder() {
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.isEmpty)
    }
    
    func testDeleteFileNotExists() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        sut.removeFile(atPath: "x")
        XCTAssertFalse(logOutput.loggedMessages.contains(where: { $0.contains("[error]") }))
    }
    
    func testFailingStoreDictionary() {
        sut.store(["date": Date() ], toPath: "")
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.isEmpty)
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
        let parallelTaskAmount = 5
        let queue = DispatchQueue(label: "testDefaultMaxEnvelopesConcurrent", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])
        
        let envelopeStoredExpectation = expectation(description: "Envelope stored")
        envelopeStoredExpectation.expectedFulfillmentCount = parallelTaskAmount
        for _ in 0..<parallelTaskAmount {
            queue.async {
                for _ in 0...(self.fixture.maxCacheItems + 5) {
                    self.sut.store(TestConstants.envelope)
                }
                envelopeStoredExpectation.fulfill()
            }
        }
        queue.activate()
        
        wait(for: [envelopeStoredExpectation], timeout: 10)

        let events = sut.getAllEnvelopes()
        XCTAssertEqual(fixture.maxCacheItems, events.count)
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
        sut.store(SentryEnvelope(session: SentrySession(releaseName: "1.0.0")))
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

    /**
     * We need to deserialize every envelope and check if it contains a session.
     */
    func testMigrateSessionInit_WorstCasePerformance() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...(fixture.maxCacheItems - 3) {
            sut.store(TestConstants.envelope)
        }

        measure {
            sut.store(TestConstants.envelope)
        }
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
        let expectedSession = SentrySession(releaseName: "1.0.0")
        sut.storeCurrentSession(expectedSession)
        let actualSession = sut.readCurrentSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
        XCTAssertNil(sut.readCrashedSession())
    }
    
    func testStoreAndReadCrashedSession() {
        let expectedSession = SentrySession(releaseName: "1.0.0")
        sut.storeCrashedSession(expectedSession)
        let actualSession = sut.readCrashedSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
    }

    func testStoreDeleteCurrentSession() {
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0"))
        sut.deleteCurrentSession()
        let actualSession = sut.readCurrentSession()
        XCTAssertNil(actualSession)
    }
    
    func testStoreDeleteCrashedSession() {
        sut.storeCrashedSession(SentrySession(releaseName: "1.0.0"))
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
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.1"))
        
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

    func testReadGarbageTimezoneOffset() throws {
        try "garbage".write(to: URL(fileURLWithPath: sut.timezoneOffsetFilePath), atomically: true, encoding: .utf8)
        XCTAssertNil(sut.readTimezoneOffset())
    }

    private func givenMaximumEnvelopes() {
        fixture.eventIds.forEach { id in
            let envelope = SentryEnvelope(id: id, singleItem: SentryEnvelopeItem(event: Event()))

            sut.store(envelope)
            advanceTime(bySeconds: 0.1)
        }
    }

    private func givenGarbageInEnvelopesFolder() {
        do {
            try "garbage".write(to: URL(fileURLWithPath: "\(sut.envelopesPath)/garbage.json"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to store garbage in Envelopes folder.")
        }
    }
    
    private func givenOldEnvelopes() throws {
        let envelope = TestConstants.envelope
        let path = sut.store(envelope)

        let timeIntervalSince1970 = fixture.currentDateProvider.date().timeIntervalSince1970 - (90 * 24 * 60 * 60)
        let date = Date(timeIntervalSince1970: timeIntervalSince1970 - 1)
        try FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: path)

        XCTAssertEqual(sut.getAllEnvelopes().count, 1)
    }

    private func storeEvent() {
        do {
            // Store a fake event to the events folder
            try FileManager.default.createDirectory(atPath: sut.eventsPath, withIntermediateDirectories: true, attributes: nil)
            try "fake event".write(to: URL(fileURLWithPath: "\(sut.eventsPath)/event.json"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to store fake event.")
        }
    }
    
    private func setImmutableForAppState(immutable: Bool) {
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

    private func setImmutableForTimezoneOffset(immutable: Bool) {
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

    private func assertEventFolderDoesntExist() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: sut.eventsPath),
                        "Folder for events should be deleted on init: \(sut.eventsPath)")
    }

    private func assertSessionInitMoved(_ actualSessionFileContents: SentryFileContents) {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: actualSessionEnvelope?.items[1].data ?? Data())
        XCTAssertNotNil(actualSession)

        XCTAssertEqual(fixture.expectedSessionUpdate, actualSession)
    }
    
    private func assertSessionInitNotMoved(_ actualSessionFileContents: SentryFileContents) {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: actualSessionEnvelope?.items[0].data ?? Data())
        XCTAssertNotNil(actualSession)

        XCTAssertEqual(fixture.sessionUpdate, actualSession)
    }

    private func assertSessionEnvelopesStored(count: Int) {
        let fileContentsWithSession = sut.getAllEnvelopes().filter { envelopeFileContents in
            let envelope = SentrySerialization.envelope(with: envelopeFileContents.contents)
            return !(envelope?.items.filter { item in item.header.type == SentryEnvelopeItemTypeSession }.isEmpty ?? false)
        }

        XCTAssertEqual(count, fileContentsWithSession.count)
    }
    
    private func assertValidAppStateStored() {
        let actual = sut.readAppState()
        XCTAssertEqual(TestData.appState, actual)
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
    
    private class AppStateWithFaultySerialization: SentryAppState {
        override func serialize() -> [String: Any] {
            return ["app": self]
        }
    }
}
