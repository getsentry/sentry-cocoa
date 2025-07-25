// swiftlint:disable file_length

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        
        init() throws {
            currentDateProvider = TestCurrentDateProvider()
            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            
            eventIds = (0...(maxCacheItems + 10)).map { _ in SentryId() }
            
            options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryFileManagerTests.self)

            sessionEnvelope = SentryEnvelope(session: session)
            
            let sessionCopy = try XCTUnwrap(session.copy() as? SentrySession)
            sessionCopy.incrementErrors()
            // We need to serialize in order to set the timestamp and the duration
            sessionUpdate = SentrySession(jsonObject: sessionCopy.serialize())!
            
            let event = Event()
            let items = [SentryEnvelopeItem(session: sessionUpdate), SentryEnvelopeItem(event: event)]
            sessionUpdateEnvelope = SentryEnvelope(id: event.eventId, items: items)
            
            let sessionUpdateCopy = try XCTUnwrap(sessionUpdate.copy() as? SentrySession)
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

        func getValidDirectoryPath() -> String {
            URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("SentryTest")
                .path
        }

        func getTooLongPath() -> String {
            var url = URL(fileURLWithPath: NSTemporaryDirectory())
            for element in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"] {
                url = url.appendingPathComponent(Array(
                    repeating: element,
                    count: Int(NAME_MAX)
                ).joined())
            }
            return url.path
        }

        func getInvalidPath() -> String {
            URL(fileURLWithPath: "/dev/null").path
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryFileManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
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
        sut.deleteAbnormalSession()
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
        
        let expectedData = try XCTUnwrap(SentrySerialization.data(with: envelope))
        
        let envelopes = sut.getAllEnvelopes()
        XCTAssertEqual(1, envelopes.count)
        
        let actualData = try XCTUnwrap(envelopes.first).contents
        XCTAssertEqual(expectedData, actualData as Data)
    }
    
    func testStoreInvalidEnvelope_ReturnsNil() {
        let sdkInfoWithInvalidJSON = SentrySdkInfo(name: SentryInvalidJSONString() as String, version: "8.0.0", integrations: [], features: [], packages: [])
        let headerWithInvalidJSON = SentryEnvelopeHeader(id: nil, sdkInfo: sdkInfoWithInvalidJSON, traceContext: nil)
        
        let envelope = SentryEnvelope(header: headerWithInvalidJSON, items: [])
        
        XCTAssertNil(sut.store(envelope))
    }
    
    func testDeleteOldEnvelopes() throws {
        try givenOldEnvelopes()
        
        sut = fixture.getSut()
        sut.deleteOldEnvelopeItems()
        
        XCTAssertEqual(sut.getAllEnvelopes().count, 0)
    }
    
    func testDeleteOldEnvelopes_LogsIgnoreDSStoreFiles() throws {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let dsStoreFile = "\(sut.basePath)/.DS_Store"
        
        let result = FileManager.default.createFile(atPath: dsStoreFile, contents: Data("some data".utf8))
        XCTAssertEqual(result, true)
        
        sut.deleteOldEnvelopeItems()
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [debug]") &&
            $0.contains("Ignoring .DS_Store file when building envelopes path at path: \(dsStoreFile)")
        }
        XCTAssertEqual(logMessages.count, 1)
        
        try FileManager.default.removeItem(atPath: dsStoreFile)
    }
    
    func testDeleteOldEnvelopes_LogsDebugForTextFiles() throws {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let sut = fixture.getSut()
        
        let textFilePath = "\(sut.basePath)/something.txt"
        
        let result = FileManager.default.createFile(atPath: textFilePath, contents: Data("some data".utf8))
        XCTAssertEqual(result, true)
        
        sut.deleteOldEnvelopeItems()
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [debug]") &&
            $0.contains("Ignoring non directory when deleting old envelopes at path: \(textFilePath)")
        }
        XCTAssertEqual(logMessages.count, 1)
        
        try FileManager.default.removeItem(atPath: textFilePath)
    }
    
    func testGetEnvelopesPath_ForNonExistentPath_LogsWarning() throws {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let sut = fixture.getSut()
        
        let nonExistentFile = "nonExistentFile.txt"
        let nonExistentFileFullPath = "\(sut.basePath)/\(nonExistentFile)"
        
        XCTAssertNil(sut.getEnvelopesPath(nonExistentFile))
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [warning]") &&
            $0.contains("Could not get attributes of item at path: \(nonExistentFileFullPath)")
        }
        XCTAssertEqual(logMessages.count, 1)
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
        let path = try XCTUnwrap(sut.store(envelope))
        
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
        SentrySDKLog.setLogOutput(logOutput)
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
    
    func testMigrateSessionInit_SessionUpdateIsLast() throws {
        sut.store(fixture.sessionEnvelope)
        // just some other session
        sut.store(SentryEnvelope(session: SentrySession(releaseName: "1.0.0", distinctId: "some-id")))
        for _ in 0...(fixture.maxCacheItems - 3) {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        
        try assertSessionInitMoved(sut.getAllEnvelopes().last!)
        assertSessionEnvelopesStored(count: 2)
    }
    
    func testMigrateSessionInit_SessionUpdateIsSecond() throws {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...(fixture.maxCacheItems - 2) {
            sut.store(TestConstants.envelope)
        }
        
        try assertSessionInitMoved(sut.getAllEnvelopes().first!)
        assertSessionEnvelopesStored(count: 1)
    }
    
    func testMigrateSessionInit_IsInMiddle() throws {
        sut.store(fixture.sessionEnvelope)
        for _ in 0...10 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...18 {
            sut.store(TestConstants.envelope)
        }
        
        try assertSessionInitMoved(sut.getAllEnvelopes()[10])
        assertSessionEnvelopesStored(count: 1)
    }
    
    func testMigrateSessionInit_MovesInitFlagOnlyToFirstSessionUpdate() throws {
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
        
        try assertSessionInitMoved(sut.getAllEnvelopes()[10])
        try assertSessionInitNotMoved(sut.getAllEnvelopes()[11])
        try assertSessionInitNotMoved(sut.getAllEnvelopes()[12])
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
    
    func testMigrateSessionInit_FailToLoadEnvelope() throws {
        sut.store(fixture.sessionEnvelope)
        
        for _ in 0...(fixture.maxCacheItems - 3) {
            sut.store(TestConstants.envelope)
        }
        
        // Trying to load the file content of a directory is going to return nil for the envelope.
        let envelopePath = try XCTUnwrap(sut.store(TestConstants.envelope))
        let fileManager = FileManager.default
        try! fileManager.removeItem(atPath: envelopePath)
        try! fileManager.createDirectory(atPath: envelopePath, withIntermediateDirectories: false, attributes: nil)
        
        sut.store(fixture.sessionUpdateEnvelope)
        
        try assertSessionInitMoved(sut.getAllEnvelopes().last!)
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
        
        XCTAssertEqual(try XCTUnwrap(fixture.eventIds.element(at: 11)), actualEnvelope?.header.eventId)
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
    
    func testStoreAbnormalSession() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.abnormalMechanism = "anr_foreground"
        
        // Act
        sut.storeAbnormalSession(session)
        
        // Assert
        let actualSession = try XCTUnwrap(sut.readAbnormalSession())
        
        // Only assert a few properties. SentrySessionTests tests the serialization
        XCTAssertEqual(session.sessionId, actualSession.sessionId)
        XCTAssertEqual(session.distinctId, actualSession.distinctId)
        XCTAssertEqual(session.releaseName, actualSession.releaseName)
        XCTAssertEqual(session.abnormalMechanism, actualSession.abnormalMechanism)
    }
    
    func testDeleteAbnormalSession() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.abnormalMechanism = "anr_foreground"
        sut.storeAbnormalSession(session)
        
        // Act
        sut.deleteAbnormalSession()
        
        // Assert
        XCTAssertNil(sut.readAbnormalSession())
    }
    
    func testDeleteAbnormalSession_WhenNoAbnormalSessionStored_DoesNotCrash() throws {
        sut.deleteAbnormalSession()
    }
    
    func testReadAbnormalSession_NoSessionStored () throws {
        XCTAssertNil(sut.readAbnormalSession())
    }
    
    func testAbnormalSessionAsync_DoesNotCrash() {
        // Arrange

        // Using 100 iterations because it's still enough to find race conditions and
        // synchronization issues that could lead to crashes, but it's small enough to not
        // time out in CI.
        // If you want to use this to find synchronization issues, you should increase the number of iterations.
        let iterations = 100
        let expectation = expectation(description: "complete all abnormal session interactions")
        expectation.expectedFulfillmentCount = iterations * 3
        let dispatchQueue = DispatchQueue(label: "testAbnormalSessionAsync_DoesNotCrash", qos: .userInitiated, attributes: [.concurrent])
        
        // Act
        for _ in 0..<iterations {
            dispatchQueue.async {
                self.sut.storeAbnormalSession(SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
                expectation.fulfill()
            }
            
            dispatchQueue.async {
                self.sut.readAbnormalSession()
                expectation.fulfill()
            }
            
            dispatchQueue.async {
                self.sut.deleteAbnormalSession()
                expectation.fulfill()
            }
        }
        
        // Assert
        waitForExpectations(timeout: 10)
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
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        sut.deleteAllFolders()
        sut.getAllEnvelopes()
        
        let debugLogMessages = logOutput.loggedMessages.filter { $0.contains("[Sentry] [info]") && $0.contains("Returning empty files list, as folder doesn't exist at path:") }
        XCTAssertEqual(debugLogMessages.count, 1)
        
        let errorMessages = logOutput.loggedMessages.filter { $0.contains("[Sentry] [error]") }
        
        XCTAssertEqual(errorMessages.count, 0)
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
    
    func testStoreWriteAppHangEvent() throws {
        // Arrange
        let event = TestData.event
        sut.storeAppHang(event)
        
        // Act
        let actualEvent = try XCTUnwrap(sut.readAppHangEvent())
        
        // Assert
        XCTAssertEqual(event.eventId, actualEvent.eventId)
        XCTAssertEqual(event.timestamp, actualEvent.timestamp)
        XCTAssertEqual(event.level, actualEvent.level)
        XCTAssertEqual(event.message?.message, actualEvent.message?.message)
        XCTAssertEqual(event.platform, actualEvent.platform)
    }

    func testReadAppHangEvent_WhenNoAppHangEvent_ReturnsNil() {
        XCTAssertNil(sut.readAppHangEvent())
    }

    func testReadAppHangEvent_WithGarbage_ReturnsNil() throws {
        // Arrange
        let fileManager = FileManager.default
        let appHangEventFilePath = try XCTUnwrap(Dynamic(sut).appHangEventFilePath.asString)
        
        fileManager.createFile(atPath: appHangEventFilePath, contents: Data("garbage".utf8), attributes: nil)

        // Act
        XCTAssertNil(sut.readAppHangEvent())
    }
    
    func testStoreAppHangEvent_WithInvalidJSON_ReturnsNil() {
        // Arrange
        let event = TestData.event
        event.message = SentryMessage(formatted: SentryInvalidJSONString() as String)
        
        // Act
        sut.storeAppHang(event)
        
        // Assert
        XCTAssertNil(sut.readAppHangEvent())
    }
    
    func testAppHangEventExists_WithStoredEvent_ReturnsTrue() throws {
        // Arrange
        let event = TestData.event
        sut.storeAppHang(event)
        
        // Act && Assert
        XCTAssertTrue(sut.appHangEventExists())
    }
    
    func testAppHangEventExists_WithNoStoredEvent_ReturnsFalse() throws {
        // Act && Assert
        XCTAssertFalse(sut.appHangEventExists())
    }
    
    func testAppHangEventExists_WithGarbage_ReturnsTrue() throws {
        // Arrange
        let fileManager = FileManager.default
        let appHangEventFilePath = try XCTUnwrap(Dynamic(sut).appHangEventFilePath.asString)
        
        fileManager.createFile(atPath: appHangEventFilePath, contents: Data("garbage".utf8), attributes: nil)

        // Act && Assert
        XCTAssertTrue(sut.appHangEventExists())
    }

    func testDeleteAppHangEvent() {
        // Arrange
        sut.storeAppHang(TestData.event)
        
        // Act
        sut.deleteAppHangEvent()
        
        // Assert
        XCTAssertNil(sut.readAppHangEvent())
    }

    func testSentryPathFromOptionsCacheDirectoryPath() {
        fixture.options.cacheDirectoryPath = "/var/tmp"
        sut = fixture.getSut()
        
        XCTAssertTrue(sut.sentryPath.hasPrefix("/var/tmp/io.sentry"))
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testReadPreviousBreadcrumbs() throws {
        let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 2, fileManager: sut)
        let attributesProcessor = try SentryWatchdogTerminationAttributesProcessor(
            withDispatchQueueWrapper: SentryDispatchQueueWrapper(),
            scopePersistentStore: XCTUnwrap(SentryScopePersistentStore(fileManager: sut))
        )
        let observer = SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: breadcrumbProcessor,
            attributesProcessor: attributesProcessor
        )

        for count in 0..<3 {
            let crumb = TestData.crumb
            crumb.message = "\(count)"
            let serializedBreadcrumb = crumb.serialize()
            
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }
        
        sut.moveBreadcrumbsToPreviousBreadcrumbs()
        var result = sut.readPreviousBreadcrumbs()
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "0")
        result = [Any](result.dropFirst())
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "1")
        result = [Any](result.dropFirst())
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "2")
    }
    
    func testReadPreviousBreadcrumbsCorrectOrderWhenFileTwoHasMoreCrumbs() throws {
        let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 2, fileManager: sut)
        let attributesProcessor = try SentryWatchdogTerminationAttributesProcessor(
            withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
            scopePersistentStore: XCTUnwrap(SentryScopePersistentStore(fileManager: sut))
        )
        let observer = SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: breadcrumbProcessor,
            attributesProcessor: attributesProcessor
        )

        for count in 0..<5 {
            let crumb = TestData.crumb
            crumb.message = "\(count)"
            let serializedBreadcrumb = crumb.serialize()
            
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }
        
        sut.moveBreadcrumbsToPreviousBreadcrumbs()
        var result = sut.readPreviousBreadcrumbs()
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "2")
        result = [Any](result.dropFirst())
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "3")
        result = [Any](result.dropFirst())
        XCTAssertEqual(try XCTUnwrap(result.first as? NSDictionary)["message"] as? String, "4")
    }
    
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testReadGarbageTimezoneOffset() throws {
        try "garbage".write(to: URL(fileURLWithPath: sut.timezoneOffsetFilePath), atomically: true, encoding: .utf8)
        XCTAssertNil(sut.readTimezoneOffset())
    }

    func testIsErrorPathTooLong_underlyingErrorsAvailableAndMultipleErrorsGiven_shouldUseErrorInUserInfo() throws {
        // -- Arrange --
        guard #available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *) else {
            throw XCTSkip("This test is only for macOS 11 and above")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSMultipleUnderlyingErrorsKey: [
                NSError(domain: NSCocoaErrorDomain, code: 2, userInfo: nil)
            ],
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil)
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsAvailableAndMultipleErrorsEmpty_shouldUseErrorInUserInfo() throws {
        // -- Arrange --
        guard #available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSMultipleUnderlyingErrorsKey: [Any](),
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil)
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsAvailableAndMultipleErrorsNotSet_shouldUseErrorInUserInfo() throws {
        // -- Arrange --
        guard #available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil)
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsAvailableAndOnlyMultipleErrorsGiven_shouldUseErrorFirstError() throws {
        // -- Arrange --
        guard #available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSMultipleUnderlyingErrorsKey: [
                NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil),
                NSError(domain: NSCocoaErrorDomain, code: 2, userInfo: nil)
            ]
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsNotAvailableAndErrorNotInUserInfo_shouldNotCheckError() throws {
        // -- Arrange --
        guard #unavailable(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [:])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsNotAvailableAndNonErrorInUserInfo_shouldNotCheckError() throws {
        // -- Arrange --
        guard #unavailable(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSUnderlyingErrorKey: "This is not an error"
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsErrorPathTooLong_underlyingErrorsNotAvailableAndErrorInUserInfo_shouldNotCheckError() throws {
        // -- Arrange --
        guard #unavailable(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5) else {
            throw XCTSkip("Test is disabled for this OS version")
        }
        // When accessing via `underlyingErrors`, the first result is the error set with `NSUnderlyingErrorKey`.
        // This test asserts if that behavior changes.
        let error = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil)
        ])
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsErrorPathTooLong_errorIsEnameTooLong_shouldReturnTrue() throws {
        // -- Arrange --
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG), userInfo: nil)
        // -- Act --
        let result = isErrorPathTooLong(error)
        // -- Assert --
        XCTAssertTrue(result)
    }

    func testCreateDirectoryIfNotExists_successful_shouldNotLogError() throws {
        // -- Arrange -
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let path = fixture.getValidDirectoryPath()
        var error: NSError?
        // -- Act --
        let result = createDirectoryIfNotExists(path, &error)
        // -- Assert -
        XCTAssertTrue(result)
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testCreateDirectoryIfNotExists_pathTooLogError_shouldLogError() throws {
        // -- Arrange -
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let path = fixture.getTooLongPath()
        var error: NSError?
        // -- Act --
        let result = createDirectoryIfNotExists(path, &error)
        // -- Assert -
        XCTAssertFalse(result)
        XCTAssertEqual(error?.domain, SentryErrorDomain)
        XCTAssertEqual(error?.code, 108)
        XCTAssertEqual(logOutput.loggedMessages.count, 1)
    }

    func testCreateDirectoryIfNotExists_otherError_shouldNotLogError() throws {
        // -- Arrange -
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let path = fixture.getInvalidPath()
        var error: NSError?
        // -- Act --
        let result = createDirectoryIfNotExists(path, &error)
        // -- Assert -
        XCTAssertFalse(result)
        XCTAssertEqual(error?.domain, SentryErrorDomain)
        XCTAssertEqual(error?.code, 108)
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testReadDataFromPath_whenFileExistsAtPath_shouldReadData() throws {
        // -- Arrange --
        let dirUrl = URL(fileURLWithPath: fixture.getValidDirectoryPath())
        let fileUrl = dirUrl.appendingPathComponent("test.file")
        let data = Data("<TEST DATA>".utf8)

        let fm = FileManager.default
        try fm.createDirectory(at: dirUrl, withIntermediateDirectories: true)
        try data.write(to: fileUrl)

        // -- Act --
        let readData = try sut.readData(fromPath: fileUrl.path)

        // -- Assert --
        XCTAssertEqual(readData, data)
    }

    func testReadDataFromPath_whenFileExistsNotAtPath_shouldReturnNil() throws {
        // -- Arrange --
        let path = fixture.getInvalidPath()

        // -- Act & Assert --
        try XCTAssertThrowsError(sut.readData(fromPath: path))
    }

    func testWriteData_whenSentryPathDirectoryNotExists_shouldCreateDirectory() throws {
        // -- Arrange --
        let path = sut.sentryPath.appending("/test.file")
        let data = Data("<TEST DATA>".utf8)

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)

        // Check pre-conditions
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.sentryPath) {
            try fm.removeItem(atPath: sut.sentryPath)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.sentryPath))

        // -- Act --
        sut.write(data, toPath: path)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: path))
    }
}

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
// MARK: App Launch profiling tests
extension SentryFileManagerTests {
    // if app launch profiling was configured to take place
    func testAppLaunchProfileConfigFileExists_fileExists() throws {
        try ensureAppLaunchProfileConfig()
        XCTAssertEqual(appLaunchProfileConfigFileExists(), true)
    }
    
    // if app launch profiling was not configured to take place
    func testAppLaunchProfileConfigFileExists_fileDoesNotExist() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }
    
    func testsentry_appLaunchProfileConfiguration() throws {
        // -- Assert --
        let expectedTracesSampleRate = 0.12
        let expectedTracesSampleRand = 0.55
        let expectedProfilesSampleRate = 0.34
        let expectedProfilesSampleRand = 0.66

        // -- Act --
        try ensureAppLaunchProfileConfig(
            tracesSampleRate: expectedTracesSampleRate,
            tracesSampleRand: expectedTracesSampleRand,
            profilesSampleRate: expectedProfilesSampleRate,
            profilesSampleRand: expectedProfilesSampleRand
        )
        let config = sentry_persistedLaunchProfileConfigurationOptions()

        // -- Assert --
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate]).doubleValue
        let actualTracesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRand]).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate]).doubleValue
        let actualProfilesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRand]).doubleValue
        XCTAssertEqual(actualTracesSampleRate, expectedTracesSampleRate)
        XCTAssertEqual(actualTracesSampleRand, expectedTracesSampleRand)
        XCTAssertEqual(actualProfilesSampleRate, expectedProfilesSampleRate)
        XCTAssertEqual(actualProfilesSampleRand, expectedProfilesSampleRand)
    }
    
    // if a file isn't present when we expect it to be, like if there was an issue when we went to write it to disk
    func testsentry_appLaunchProfileConfiguration_noConfigurationExists() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        XCTAssertNil(sentry_persistedLaunchProfileConfigurationOptions())
    }
    
    func testWriteAppLaunchProfilingConfigFile_noCurrentFileExists() throws {
        // -- Arrange --
        try ensureAppLaunchProfileConfig(exists: false)
        
        let expectedTracesSampleRate = 0.12
        let expectedTracesSampleRand = 0.55
        let expectedProfilesSampleRate = 0.34
        let expectedProfilesSampleRand = 0.66
        writeAppLaunchProfilingConfigFile([
            kSentryLaunchProfileConfigKeyTracesSampleRate: expectedTracesSampleRate,
            kSentryLaunchProfileConfigKeyTracesSampleRand: expectedTracesSampleRand,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: expectedProfilesSampleRate,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: expectedProfilesSampleRand
        ])
        
        let config = NSDictionary(contentsOf: launchProfileConfigFileURL())
        
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate] as? NSNumber).doubleValue
        let actualTracesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRand] as? NSNumber).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate] as? NSNumber).doubleValue
        let actualProfilesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRand] as? NSNumber).doubleValue
        XCTAssertEqual(actualTracesSampleRate, expectedTracesSampleRate)
        XCTAssertEqual(actualTracesSampleRand, expectedTracesSampleRand)
        XCTAssertEqual(actualProfilesSampleRate, expectedProfilesSampleRate)
        XCTAssertEqual(actualProfilesSampleRand, expectedProfilesSampleRand)
    }
    
    // if a file is still present in the primary location, like if a crash occurred before it could be removed, or an error occurred when trying to remove it or move it to the backup location, make sure we overwrite it
    func testWriteAppLaunchProfilingConfigFile_fileAlreadyExists() throws {
        // -- Arrange --
        try ensureAppLaunchProfileConfig(exists: true, tracesSampleRate: 0.75, tracesSampleRand: 0.25, profilesSampleRate: 0.75, profilesSampleRand: 0.35)

        let expectedTracesSampleRate = 0.12
        let expectedTracesSampleRand = 0.55
        let expectedProfilesSampleRate = 0.34
        let expectedProfilesSampleRand = 0.66

        // -- Act --
        writeAppLaunchProfilingConfigFile([
            kSentryLaunchProfileConfigKeyTracesSampleRate: expectedTracesSampleRate,
            kSentryLaunchProfileConfigKeyTracesSampleRand: expectedTracesSampleRand,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: expectedProfilesSampleRate,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: expectedProfilesSampleRand
        ])
        
        // -- Assert --
        let config = NSDictionary(contentsOf: launchProfileConfigFileURL())
        
        let actualTracesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRate] as? NSNumber).doubleValue
        let actualTracesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyTracesSampleRand] as? NSNumber).doubleValue
        let actualProfilesSampleRate = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRate] as? NSNumber).doubleValue
        let actualProfilesSampleRand = try XCTUnwrap(config?[kSentryLaunchProfileConfigKeyProfilesSampleRand] as? NSNumber).doubleValue
        XCTAssertEqual(actualTracesSampleRate, expectedTracesSampleRate)
        XCTAssertEqual(actualTracesSampleRand, expectedTracesSampleRand)
        XCTAssertEqual(actualProfilesSampleRate, expectedProfilesSampleRate)
        XCTAssertEqual(actualProfilesSampleRand, expectedProfilesSampleRand)
    }
    
    func testRemoveAppLaunchProfilingConfigFile() throws {
        try ensureAppLaunchProfileConfig(exists: true)
        XCTAssertNotNil(NSDictionary(contentsOf: launchProfileConfigFileURL()))
        removeAppLaunchProfilingConfigFile()
        XCTAssertNil(NSDictionary(contentsOf: launchProfileConfigFileURL()))
    }
    
    // if there's not a file when we expect one, just make sure we don't crash
    func testRemoveAppLaunchProfilingConfigFile_noFileExists() throws {
        try ensureAppLaunchProfileConfig(exists: false)
        XCTAssertNil(NSDictionary(contentsOf: launchProfileConfigFileURL()))
        removeAppLaunchProfilingConfigFile()
        XCTAssertNil(NSDictionary(contentsOf: launchProfileConfigFileURL()))
    }
    
    func testCheckForLaunchProfilingConfigFile_URLDoesNotExist() {
        // cause the dispatch_once to initialize the internal value
        let originalURL = launchProfileConfigFileURL()

        // set to nil to simulate exceptional environments
        sentryLaunchConfigFileURL = nil

        // make sure we return a default-off value and also don't crash the call to access()
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        
        // set the original value back so other tests don't crash
        sentryLaunchConfigFileURL = (originalURL as NSURL)
    }

    func testSentryGetScopedCachesDirectory_targetIsNotMacOS_shouldReturnSamePath() throws {
#if os(macOS)
        throw XCTSkip("Test is disabled for macOS")
#else
        // -- Arrange --
        let cachesDirectoryPath = "some/path/to/caches"

        // -- Act --
        let result = sentryGetScopedCachesDirectory(cachesDirectoryPath)

        // -- Assert
        XCTAssertEqual(result, cachesDirectoryPath)
#endif // os(macOS)
    }

    func testSentryGetScopedCachesDirectory_targetIsMacOS_shouldReturnPath() throws {
#if !os(macOS)
        throw XCTSkip("Test is disabled for non macOS")
#else
        // -- Arrange --
        let cachesDirectoryPath = "some/path/to/caches"

        // -- Act --
        let result = sentryGetScopedCachesDirectory(cachesDirectoryPath)

        // -- Assert
        // Xcode unit tests are not sandboxed, therefore we expect it to use the bundle identifier to unique the path
        // The bundle identifier will then be the xctest bundle identifier
        XCTAssertEqual(result, "some/path/to/caches/com.apple.dt.xctest.tool")
#endif // os(macOS)

    }

    func testSentryBuildScopedCachesDirectoryPath_isSandboxed_shouldReturnInputPath() {
        // -- Arrange --
        let cachesDirectoryPath = "some/path/to/caches"
        let isSandboxed = true
        let bundleIdentifier: String? = nil
        let lastPathComponent: String? = nil

        // -- Act --
        let result = sentryBuildScopedCachesDirectoryPath(
            cachesDirectoryPath,
            isSandboxed,
            bundleIdentifier,
            lastPathComponent
        )

        // -- Assert --
        XCTAssertEqual(result, cachesDirectoryPath)
    }

    func test_sentryBuildScopedCachesDirectoryPath_inputCombinations() {
        // -- Arrange --
        for testCase: (isSandboxed: Bool, bundleIdentifier: String?, lastPathComponent: String?, expected: String?) in [
            // bundleIdentifier defined
            (isSandboxed: false, bundleIdentifier: "com.example.app", lastPathComponent: "AppBinaryName", expected: "some/path/to/caches/com.example.app"),
            (isSandboxed: false, bundleIdentifier: "com.example.app", lastPathComponent: "", expected: "some/path/to/caches/com.example.app"),
            (isSandboxed: false, bundleIdentifier: "com.example.app", lastPathComponent: nil, expected: "some/path/to/caches/com.example.app"),

            // bundleIdentifier zero length string
            (isSandboxed: false, bundleIdentifier: "", lastPathComponent: "AppBinaryName", expected: "some/path/to/caches/AppBinaryName"),
            (isSandboxed: false, bundleIdentifier: "", lastPathComponent: "", expected: nil),
            (isSandboxed: false, bundleIdentifier: "", lastPathComponent: nil, expected: nil),

            // bundleIdentifier nil
            (isSandboxed: false, bundleIdentifier: nil, lastPathComponent: "AppBinaryName", expected: "some/path/to/caches/AppBinaryName"),
            (isSandboxed: false, bundleIdentifier: nil, lastPathComponent: "", expected: nil),
            (isSandboxed: false, bundleIdentifier: nil, lastPathComponent: nil, expected: nil),

            // for sandboxed scenarios, always return the original path
            (isSandboxed: true, bundleIdentifier: "com.example.app", lastPathComponent: "AppBinaryName", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: "", lastPathComponent: "AppBinaryName", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: nil, lastPathComponent: "AppBinaryName", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: "com.example.app", lastPathComponent: "", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: "", lastPathComponent: "", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: nil, lastPathComponent: "", expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: "com.example.app", lastPathComponent: nil, expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: "", lastPathComponent: nil, expected: "some/path/to/caches"),
            (isSandboxed: true, bundleIdentifier: nil, lastPathComponent: nil, expected: "some/path/to/caches")
        ] {
            // -- Act --
            let result = sentryBuildScopedCachesDirectoryPath(
                "some/path/to/caches",
                testCase.isSandboxed,
                testCase.bundleIdentifier,
                testCase.lastPathComponent
            )

            // -- Assert --
            XCTAssertEqual(result, testCase.expected, "Inputs: (isSandboxed: \(testCase.isSandboxed), bundleIdentifier: \(String(describing: testCase.bundleIdentifier)), lastPathComponent: \(String(describing: testCase.lastPathComponent)), expected: \(String(describing: testCase.expected))); Output: \(String(describing: result))")
        }
    }

    func testGetSentryPathAsURL_whenSentryPathIsValid_shouldReturnUrl() throws {
        // We only cover the test case when the sentryPath is valid, because the path is built in the file manager's
        // initializer and therefore the path is always valid to begin with.

        // -- Act --
        let url = sut.getSentryPathAsURL()

        // -- Assert --
        XCTAssertEqual(url.scheme, "file")
        XCTAssertEqual(url.path, sut.sentryPath)
    }
}

// MARK: Private profiling tests
private extension SentryFileManagerTests {
    func ensureAppLaunchProfileConfig(exists: Bool = true, tracesSampleRate: Double = 1, tracesSampleRand: Double = 1.0, profilesSampleRate: Double = 1, profilesSampleRand: Double = 1.0) throws {
        let url = launchProfileConfigFileURL()
        
        if exists {
            let dict = [
                kSentryLaunchProfileConfigKeyTracesSampleRate: tracesSampleRate,
                kSentryLaunchProfileConfigKeyTracesSampleRand: tracesSampleRand,
                kSentryLaunchProfileConfigKeyProfilesSampleRate: profilesSampleRate,
                kSentryLaunchProfileConfigKeyProfilesSampleRand: profilesSampleRand
            ]
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
        let path = try XCTUnwrap(sut.store(envelope))

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

    func assertSessionInitMoved(_ actualSessionFileContents: SentryFileContents) throws {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: try XCTUnwrap(actualSessionEnvelope?.items.element(at: 1)).data)
        XCTAssertNotNil(actualSession)

        XCTAssertEqual(fixture.expectedSessionUpdate, actualSession)
    }
    
    func assertSessionInitNotMoved(_ actualSessionFileContents: SentryFileContents) throws {
        let actualSessionEnvelope = SentrySerialization.envelope(with: actualSessionFileContents.contents)
        XCTAssertEqual(2, actualSessionEnvelope?.items.count)

        let actualSession = SentrySerialization.session(with: try XCTUnwrap(actualSessionEnvelope?.items.first).data)
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
