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
    
    func testEventStoring() throws {
        let event = Event(level: SentryLevel.info)
        event.message = "message"
        sut.store(event)
        
        let events = sut.getAllStoredEventsAndEnvelopes()
        XCTAssertTrue(events.count == 1)
        
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
    
    func testEventStoringHardLimit() {
        let event = Event(level: SentryLevel.info)
        for _ in 0...20 {
            sut.store(event)
        }
        let events = sut.getAllStoredEventsAndEnvelopes()
        XCTAssertEqual(events.count, 10)
    }
    
    func testEventStoringHardLimitSet() {
        sut.maxEvents = 15
        let event = Event(level: SentryLevel.info)
        for _ in 0...20 {
            sut.store(event)
        }
        let events = sut.getAllStoredEventsAndEnvelopes()
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
    
    func testGetAllStoredEvents() {
        sut.store(TestConstants.envelope)
        sut.store(TestConstants.envelope)
        
        let result = sut.getAllStoredEventsAndEnvelopes()
        
        XCTAssertEqual(2, result.count)
    }
    
    func testStoreEnvelope() throws {
        let envelope = TestConstants.envelope
        let envelopePath = sut.store(envelope)
        
        let expectedData = try SentrySerialization.data(with: envelope)
        
        let actualData = FileManager.default.contents(atPath: envelopePath)
        
        XCTAssertEqual(expectedData, actualData)
    }
}
