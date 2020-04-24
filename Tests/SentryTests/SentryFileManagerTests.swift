import XCTest
@testable import Sentry.SentryClient
@testable import Sentry.SentryOptions

class SentryFileManagerTestss: XCTestCase {
    
    private var fileManager : SentryFileManager!
    
    override func setUp() {
        super.setUp()
        do {
            fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
        } catch {
            XCTFail("SentryFileManager could not be created")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        fileManager.deleteAllStoredEvents()
        fileManager.deleteAllFolders()
    }
    
    func testEventStoring() throws {
        let event = Event(level: SentryLevel.info)
        event.message = "message"
        fileManager.store(event)
        
        let events = fileManager.getAllStoredEvents()
        XCTAssertTrue(events.count == 1)
        
        let actualData = events[0]["data"] as! Data
        let actualDict = try JSONSerialization.jsonObject(with: actualData) as! Dictionary<String, Any>
        
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
        fileManager.store(event)
        let events = fileManager.getAllStoredEvents()
        XCTAssertTrue(events.count == 1)
        XCTAssertEqual(events[0]["data"] as! Data, jsonData)
    }
    
    func testCreateDirDoesnotThrow() throws {
        try SentryFileManager.createDirectory(atPath: "a")
    }
    
    func testAllFilesInFolder() {
        let files = fileManager.allFiles(inFolder: "x")
        XCTAssertTrue(files.count == 0)
    }
    
    func testDeleteFileNotExsists() {
        XCTAssertFalse(fileManager.removeFile(atPath: "x"))
    }
    
    func testFailingStoreDictionary() {
        fileManager.store(["date": Date() ], toPath: "")
        let files = fileManager.allFiles(inFolder: "x")
        XCTAssertTrue(files.count == 0)
    }
    
    func testEventStoringHardLimit() {
        let event = Event(level: SentryLevel.info)
        for _ in 0...20 {
            fileManager.store(event)
        }
        let events = fileManager.getAllStoredEvents()
        XCTAssertEqual(events.count, 10)
    }
    
    func testEventStoringHardLimitSet() {
        fileManager.maxEvents = 15
        let event = Event(level: SentryLevel.info)
        for _ in 0...20 {
            fileManager.store(event)
        }
        let events = fileManager.getAllStoredEvents()
        XCTAssertEqual(events.count, 15)
    }
    
    func testStoreAndReadCurrentSession() {
        let expectedSession = SentrySession()
        fileManager.storeCurrentSession(expectedSession)
        let actualSession = fileManager.readCurrentSession()
        XCTAssertTrue(expectedSession.distinctId == actualSession?.distinctId)
    }
    
    func testStoreDeleteCurrentSession() {
        fileManager.storeCurrentSession(SentrySession())
        fileManager.deleteCurrentSession()
        let actualSession = fileManager.readCurrentSession()
        XCTAssertNil(actualSession)
    }
}
