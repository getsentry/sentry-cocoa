@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

// Even if we don't run this test below OSX 10.12 we expect the actual
// implementation to be thread safe.
@available(OSX 10.12, *)
@available(iOS 10.0, *)
@available(tvOS 10.0, *)
class SentryFileManagerTests: XCTestCase {
    
    private class Fixture {
        let eventIds = (0...110).map { _ in SentryId() }

        let session = SentrySession(releaseName: "1.0.0")
        let sessionEnvelope: SentryEnvelope

        let sessionUpdate: SentrySession
        let sessionUpdateEnvelope: SentryEnvelope

        let expectedSessionUpdate: SentrySession

        let queue = DispatchQueue(label: "SentryFileManagerTests", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()

        init() {
            sessionEnvelope = SentryEnvelope(session: session)

            let sessionCopy = session.copy() as! SentrySession
            sessionCopy.incrementErrors()
            // We need to serialize in order to set the timestamp and the duration
            sessionUpdate = SentrySession(jsonObject: sessionCopy.serialize())

            let event = Event()
            let items = [SentryEnvelopeItem(session: sessionUpdate), SentryEnvelopeItem(event: event)]
            sessionUpdateEnvelope = SentryEnvelope(id: event.eventId, items: items)

            let sessionUpdateCopy = sessionUpdate.copy() as! SentrySession
            // We need to serialize in order to set the timestamp and the duration
            expectedSessionUpdate = SentrySession(jsonObject: sessionUpdateCopy.serialize())
            // We can only set the init flag after serialize, because the duration is not set if the init flag is set
            expectedSessionUpdate.setFlagInit()
        }

    }

    private var fixture: Fixture!
    private var sut: SentryFileManager!
    private var currentDateProvider: TestCurrentDateProvider!

    override func setUp() {
        super.setUp()
        do {
            currentDateProvider = TestCurrentDateProvider()
            CurrentDate.setCurrentDateProvider(currentDateProvider)

            fixture = Fixture()

            sut = try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: currentDateProvider)

            sut.deleteAllEnvelopes()
            sut.deleteTimestampLastInForeground()
        } catch {
            XCTFail("SentryFileManager could not be created")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        sut.deleteAllEnvelopes()
        sut.deleteAllFolders()
        sut.deleteTimestampLastInForeground()
    }
    
    func testInitDoesNotOverrideDirectories() throws {
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0"))
        sut.storeTimestampLast(inForeground: Date())

        _ = try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        let fileManager = try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())

        XCTAssertEqual(1, fileManager.getAllEnvelopes().count)
        XCTAssertNotNil(fileManager.readCurrentSession())
        XCTAssertNotNil(fileManager.readTimestampLastInForeground())
    }
    
    func testInitDeletesEventsFolder() throws {
        storeEvent()
        
        _ = try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        
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
    
    func testCreateDirDoesNotThrow() throws {
        try SentryFileManager.createDirectory(atPath: "a")
    }
    
    func testAllFilesInFolder() {
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.isEmpty)
    }
    
    func testDeleteFileNotExists() {
        XCTAssertFalse(sut.removeFile(atPath: "x"))
    }
    
    func testFailingStoreDictionary() {
        sut.store(["date": Date() ], toPath: "")
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.isEmpty)
    }

    func testDefaultMaxEnvelopes() {
        for _ in 0...100 {
            sut.store(TestConstants.envelope)
        }

        let events = sut.getAllEnvelopes()
        XCTAssertEqual(events.count, 100)
    }

    func testDefaultMaxEnvelopesConcurrent() {
        for _ in 0...1_000 {
            storeAsync(envelope: TestConstants.envelope)
        }
        fixture.queue.activate()
        fixture.group.waitWithTimeout()

        let events = sut.getAllEnvelopes()
        XCTAssertEqual(events.count, 100)
    }
    
    func testMaxEnvelopesSet() {
        sut.maxEnvelopes = 15
        for _ in 0...15 {
            sut.store(TestConstants.envelope)
        }
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(events.count, 15)
    }

    func testMigrateSessionInit_SessionUpdateIsLast() {
        sut.store(fixture.sessionEnvelope)
        // just some other session
        sut.store(SentryEnvelope(session: SentrySession(releaseName: "1.0.0")))
        for _ in 0...97 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)

        assertSessionInitMoved(sut.getAllEnvelopes().last!)
        assertSessionEnvelopesStored(count: 2)
    }

    func testMigrateSessionInit_SessionUpdateIsSecond() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...98 {
            sut.store(TestConstants.envelope)
        }

        assertSessionInitMoved(sut.getAllEnvelopes().first!)
        assertSessionEnvelopesStored(count: 1)
    }

    func testMigrateSessionInit_IsInMiddle() {
        sut.store(fixture.sessionEnvelope)
        for _ in 0...50 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...48 {
            sut.store(TestConstants.envelope)
        }

        assertSessionInitMoved(sut.getAllEnvelopes()[50])
        assertSessionEnvelopesStored(count: 1)
    }
    
    func testMigrateSessionInit_MovesInitFlagOnlyToFirstSessionUpdate() {
        sut.store(fixture.sessionEnvelope)
        for _ in 0...50 {
            sut.store(TestConstants.envelope)
        }
        sut.store(fixture.sessionUpdateEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...46 {
            sut.store(TestConstants.envelope)
        }

        assertSessionInitMoved(sut.getAllEnvelopes()[50])
        assertSessionInitNotMoved(sut.getAllEnvelopes()[51])
        assertSessionInitNotMoved(sut.getAllEnvelopes()[52])
        assertSessionEnvelopesStored(count: 3)
    }

    func testMigrateSessionInit_NoOtherSessionUpdate() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...99 {
            sut.store(TestConstants.envelope)
        }

        assertSessionEnvelopesStored(count: 0)
    }
    
    func testMigrateSessionInit_FailToLoadEnvelope() {
        sut.store(fixture.sessionEnvelope)
        
        for _ in 0...97 {
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

    /**
     * We need to deserialize every envelope and check if it contains a session.
     */
    func testMigrateSessionInit_WorstCasePerformance() {
        sut.store(fixture.sessionEnvelope)
        sut.store(fixture.sessionUpdateEnvelope)
        for _ in 0...97 {
            sut.store(TestConstants.envelope)
        }

        measure {
            sut.store(TestConstants.envelope)
        }
    }

    func testGetAllEnvelopesAreSortedByDateAscending() {
        given100Envelopes()

        let envelopes = sut.getAllEnvelopes()

        // Envelopes are sorted ascending by date and only the latest 100 are kept
        let expectedEventIds = Array(fixture.eventIds[11...110])

        XCTAssertEqual(100, envelopes.count)
        for i in 0...99 {
            let envelope = SentrySerialization.envelope(with: envelopes[i].contents)
            let actualEventId = envelope?.header.eventId
            XCTAssertEqual(expectedEventIds[i], actualEventId)
        }
    }

    func testGetOldestEnvelope() {
        given100Envelopes()

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

    private func storeAsync(envelope: SentryEnvelope) {
        fixture.group.enter()
        fixture.queue.async {
            self.sut.store(envelope)
            self.fixture.group.leave()
        }
    }

    private func given100Envelopes() {
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

    private func storeEvent() {
        do {
            // Store a fake event to the events folder
            try FileManager.default.createDirectory(atPath: sut.eventsPath, withIntermediateDirectories: true, attributes: nil)
            try "fake event".write(to: URL(fileURLWithPath: "\(sut.eventsPath)/event.json"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to store fake event.")
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

    private func advanceTime(bySeconds: TimeInterval) {
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(bySeconds))
    }
}
