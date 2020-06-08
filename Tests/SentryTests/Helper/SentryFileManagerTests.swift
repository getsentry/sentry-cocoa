@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions
import XCTest

class SentryFileManagerTests: XCTestCase {
    
    private var sut: SentryFileManager!
    
    override func setUp() {
        super.setUp()
        do {
            sut = try SentryFileManager(dsn: TestConstants.dsn)
        } catch {
            XCTFail("SentryFileManager could not be created")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        sut.deleteAllStoredEventsAndEnvelopes()
        sut.deleteAllFolders()
        sut.deleteTimestampLastInForeground()
    }
    
    func testInitDoesNotOverrideDirectories() throws {
        sut.store(Event())
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.0"))
        sut.storeTimestampLast(inForeground: Date())

        _ = try SentryFileManager(dsn: TestConstants.dsn)
        let fileManager = try SentryFileManager(dsn: TestConstants.dsn)
        
        XCTAssertEqual(1, fileManager.getAllEventsAndMaybeEnvelopes().count)
        XCTAssertEqual(1, fileManager.getAllEnvelopes().count)
        XCTAssertNotNil(fileManager.readCurrentSession())
        XCTAssertNotNil(fileManager.readTimestampLastInForeground())
    }
    
    func testEventStoring() throws {
        let event = Event(level: SentryLevel.info)
        event.message = "message"
        sut.store(event)
        
        let events = sut.getAllEventsAndMaybeEnvelopes()
        XCTAssertTrue(events.count == 1)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)

        // swiftlint:disable force_cast
        // swiftlint:disable force_unwrapping
        let actualDict = try JSONSerialization.jsonObject(with: events[0].contents) as! [String: Any]
        // swiftlint:enable force_unwrapping
        
        let eventDict = event.serialize()
        XCTAssertEqual(eventDict.count, actualDict.count)
        XCTAssertEqual(eventDict["message"] as! String, actualDict["message"] as! String)
        XCTAssertEqual(eventDict["timestamp"] as! String, actualDict["timestamp"] as! String)
        XCTAssertEqual(eventDict["event_id"] as! String, actualDict["event_id"] as! String)
        XCTAssertEqual(eventDict["level"] as! String, actualDict["level"] as! String)
        XCTAssertEqual(eventDict["platform"] as! String, actualDict["platform"] as! String)
        // swiftlint:enable force_cast
    }
    
    func testEventDataStoring() throws {
        let jsonData: Data = try JSONSerialization.data(withJSONObject: ["id", "1234"])
        
        let event = Event(json: jsonData)
        sut.store(event)
        let events = sut.getAllStoredEventsAndEnvelopes()
        XCTAssertTrue(events.count == 1)
        XCTAssertEqual(events[0].contents, (jsonData as NSData) as Data)
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
    
    func testDefaultMaxEvents() {
        for _ in 0...10 {
            sut.store(Event(level: SentryLevel.info))
        }
        let events = sut.getAllEventsAndMaybeEnvelopes()
        XCTAssertEqual(events.count, 10)
    }
    
    func testMaxEventsSet() {
        sut.maxEvents = 15
        sut.maxEnvelopes = 14
        for _ in 0...15 {
            sut.store(Event(level: SentryLevel.info))
        }
        let events = sut.getAllEventsAndMaybeEnvelopes()
        XCTAssertEqual(events.count, 15)
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
        sut.maxEvents = 14
        for _ in 0...15 {
            sut.store(TestConstants.envelope)
        }
        let events = sut.getAllEnvelopes()
        XCTAssertEqual(events.count, 15)
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
        sut.store(Event())
        
        XCTAssertEqual(3, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(2, sut.getAllEnvelopes().count)
        XCTAssertEqual(1, sut.getAllEventsAndMaybeEnvelopes().count)
    }
    
    func testDeleteAllFolders() {
        sut.store(TestConstants.envelope)
        sut.store(Event())
        sut.storeCurrentSession(SentrySession(releaseName: "1.0.1"))
        
        sut.deleteAllFolders()
        
        XCTAssertEqual(0, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEventsAndMaybeEnvelopes().count)
        XCTAssertNil(sut.readCurrentSession())
    }
    
    func testDeleteAllStoredEventsAndEnvelopes() {
        sut.store(TestConstants.envelope)
        sut.store(Event())
        
        sut.deleteAllStoredEventsAndEnvelopes()
        
        XCTAssertEqual(0, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEventsAndMaybeEnvelopes().count)
    }
}
