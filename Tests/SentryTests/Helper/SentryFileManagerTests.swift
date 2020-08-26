@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryFileManagerTests: XCTestCase {
    
    private class Fixture {
        let eventIds = (0...110).map { _ in SentryId() }
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
    
    func testMaxEnvelopesSet() {
        sut.maxEnvelopes = 15
        for _ in 0...15 {
            sut.store(TestConstants.envelope)
        }
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(events.count, 15)
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
    }

    func testStoreDeleteCurrentSession() {
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0"))
        sut.deleteCurrentSession()
        let actualSession = sut.readCurrentSession()
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

    private func advanceTime(bySeconds: TimeInterval) {
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(bySeconds))
    }
}
