import XCTest

class SentrySessionTestsSwift: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
    }
    
    func testEndSession() {
        let session = SentrySession(releaseName: "0.1.0")
        let date = currentDateProvider.date().addingTimeInterval(1)
        session.endExited(withTimestamp: date)
        
        XCTAssertEqual(1, session.duration)
        XCTAssertEqual(date, session.timestamp)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
    }
    
    func testInitAndDurationNilWhenSerialize() {
        let session1 = SentrySession(releaseName: "1.4.0")
        var json = session1.serialize()
        json.removeValue(forKey: "init")
        json.removeValue(forKey: "duration")
        
        let date = currentDateProvider.date().addingTimeInterval(2)
        json["timestamp"] = (date as NSDate).sentry_toIso8601String()
        let session = SentrySession(jsonObject: json)
        
        let sessionSerialized = session.serialize()
        let duration = sessionSerialized["duration"] as? Double ?? -1
        XCTAssertEqual(2, duration)
    }
    
    func testCopySession() {
        let session = SentrySession(releaseName: "1.0.0")
        let copiedSession = session.copy() as! SentrySession
        
        XCTAssertEqual(session, copiedSession)
        
        let user = User()
        user.email = "someone@sentry.io"
        session.user = user
        XCTAssertNotEqual(session, copiedSession)
    }
}
