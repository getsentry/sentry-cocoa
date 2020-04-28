import XCTest
@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions

class SentryFileManagerTests: XCTestCase {
    
    private var sut : SentryFileManager!
    
    override func setUp() {
        super.setUp()
        do {
            sut = try SentryFileManager.init(dsn: TestConstants.dsn)
        } catch {
            XCTFail("SentryFileManager could not be created")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        sut.deleteAllStoredEventsAndEnvelopes()
        sut.deleteAllFolders()
    }
    
    func testInitDoesNotOverrideDirectories() throws {
        sut.store(Event())
        sut.store(TestConstants.envelope)
        sut.storeCurrentSession(SentrySession())
        
        _ = try SentryFileManager.init(dsn: TestConstants.dsn)
        let fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
        
        XCTAssertEqual(1, fileManager.getAllEvents().count)
        XCTAssertEqual(1, fileManager.getAllEnvelopes().count)
        XCTAssertNotNil(fileManager.readCurrentSession())
    }
    
    func testEventStoring() throws {
        let event = Event(level: SentryLevel.info)
        event.message = "message"
        sut.store(event)
        
        let events = sut.getAllEvents()
        XCTAssertTrue(events.count == 1)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        
        let actualDict = try JSONSerialization.jsonObject(with: events[0].contents! as Data) as! Dictionary<String, Any>
        
        let eventDict = event.serialize()
        XCTAssertEqual(eventDict.count, actualDict.count)
        XCTAssertEqual(eventDict["message"] as! String, actualDict["message"] as! String)
        XCTAssertEqual(eventDict["timestamp"] as! String, actualDict["timestamp"] as! String)
        XCTAssertEqual(eventDict["event_id"] as! String, actualDict["event_id"] as! String)
        XCTAssertEqual(eventDict["level"] as! String, actualDict["level"] as! String)
        XCTAssertEqual(eventDict["platform"] as! String, actualDict["platform"] as! String)
    }
    
    func testEventDataStoring() throws {
        let jsonData : Data = try JSONSerialization.data(withJSONObject: ["id", "1234"])
        
        let event = Event(json: jsonData)
        sut.store(event)
        let events = sut.getAllStoredEventsAndEnvelopes()
        XCTAssertTrue(events.count == 1)
        XCTAssertEqual(events[0].contents, jsonData as NSData)
    }
    
    func testStoreEnvelope() throws {
        let envelope = TestConstants.envelope
        sut.store(envelope)
        
        let expectedData = try SentrySerialization.data(with: envelope)
        
        let envelopes = sut.getAllEnvelopes()
        XCTAssertEqual(1, envelopes.count)
        
        let actualData = envelopes[0].contents! as Data
        XCTAssertEqual(expectedData, actualData)
    }
    
    func testCreateDirDoesnotThrow() throws {
        try SentryFileManager.createDirectory(atPath: "a")
    }
    
    func testAllFilesInFolder() {
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.count == 0)
    }
    
    func testDeleteFileNotExsists() {
        XCTAssertFalse(sut.removeFile(atPath: "x"))
    }
    
    func testFailingStoreDictionary() {
        sut.store(["date": Date() ], toPath: "")
        let files = sut.allFiles(inFolder: "x")
        XCTAssertTrue(files.count == 0)
    }
    
    func testDefaultMaxEvents() {
        for _ in 0...10 {
            sut.store(Event(level: SentryLevel.info))
        }
        let events = sut.getAllEvents()
        XCTAssertEqual(events.count, 10)
    }
    
    func testMaxEventsSet() {
        sut.maxEvents = 15
        sut.maxEnvelopes = 14
        for _ in 0...15 {
            sut.store(Event(level: SentryLevel.info))
        }
        let events = sut.getAllEvents()
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
        let expectedSession = SentrySession()
        sut.storeCurrentSession(expectedSession)
        let actualSession = sut.readCurrentSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
    }
    
    func testStoreDeleteCurrentSession() {
        sut.storeCurrentSession(SentrySession())
        sut.deleteCurrentSession()
        let actualSession = sut.readCurrentSession()
        XCTAssertNil(actualSession)
    }
    
    func testGetAllStoredEventsAndEnvelopes() {
        sut.store(TestConstants.envelope)
        sut.store(TestConstants.envelope)
        sut.store(Event())
        
        XCTAssertEqual(3, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(2, sut.getAllEnvelopes().count)
        XCTAssertEqual(1, sut.getAllEvents().count)
    }
    
    func testDeleteAllFolders() {
        sut.store(TestConstants.envelope)
        sut.store(Event())
        sut.storeCurrentSession(SentrySession())
        
        sut.deleteAllFolders()
        
        XCTAssertEqual(0, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEvents().count)
        XCTAssertNil(sut.readCurrentSession())
    }
    
    func testDeleteAllStoredEventsAndEnvelopes() {
        sut.store(TestConstants.envelope)
        sut.store(Event())
        
        sut.deleteAllStoredEventsAndEnvelopes()
        
        XCTAssertEqual(0, sut.getAllStoredEventsAndEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEnvelopes().count)
        XCTAssertEqual(0, sut.getAllEvents().count)
    }
}
