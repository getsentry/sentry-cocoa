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
        let user = User()
        user.email = "someone@sentry.io"

        let session = SentrySession(releaseName: "1.0.0")
        session.user = user
        let copiedSession = session.copy() as! SentrySession

        XCTAssertEqual(session, copiedSession)

        // The user is copied as well
        session.user?.email = "someone_else@sentry.io"
        XCTAssertNotEqual(session, copiedSession)
    }
    
    func testInitWithJson_IfJsonMissesField_DefaultValuesAreUsed() {
        let expected = SentrySession(releaseName: "release")
        var serialized = expected.serialize()
        serialized["sid"] = nil
        serialized["started"] = nil
        serialized["status"] = nil
        serialized["seq"] = nil
        serialized["errors"] = nil
        serialized["did"] = nil
        serialized["init"] = nil
        serialized["attrs"] = nil

        let session = SentrySession(jsonObject: serialized)
        
        XCTAssertNotEqual(expected.sessionId, session.sessionId)
        XCTAssertEqual(expected.started, session.started)
        XCTAssertEqual(expected.status, session.status)
        XCTAssertEqual(expected.sequence, session.sequence)
        XCTAssertEqual(expected.errors, session.errors)
        XCTAssertNil(session.releaseName)
    }
}
