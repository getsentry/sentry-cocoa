import XCTest

class SentrySessionTestsSwift: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    
    override func setUp() {
        super.setUp()
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
        guard let session = SentrySession(jsonObject: json) else {
            XCTFail("Couldn't create session from JSON"); return
        }
        
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
    
    func testInitWithJson_Status_MapsToCorrectStatus() {
        func testStatus(status: SentrySessionStatus, statusAsString: String) {
            let expected = SentrySession(releaseName: "release")
            var serialized = expected.serialize()
            serialized["status"] = statusAsString
            let actual = SentrySession(jsonObject: serialized)!
            XCTAssertEqual(status, actual.status)
        }
        
        testStatus(status: SentrySessionStatus.ok, statusAsString: "ok")
        testStatus(status: SentrySessionStatus.exited, statusAsString: "exited")
        testStatus(status: SentrySessionStatus.crashed, statusAsString: "crashed")
        testStatus(status: SentrySessionStatus.abnormal, statusAsString: "abnormal")
    }
    
    func testInitWithJson_IfJsonMissesField_SessionIsNil() {
        withValue { $0["sid"] = nil }
        withValue { $0["started"] = nil }
        withValue { $0["status"] = nil }
        withValue { $0["seq"] = nil }
        withValue { $0["errors"] = nil }
        withValue { $0["did"] = nil }
    }
    
    func testInitWithJson_IfJsonContainsWrongFields_SessionIsNil() {
        withValue { $0["sid"] = 20 }
        withValue { $0["started"] = 20 }
        withValue { $0["status"] = 20 }
        withValue { $0["seq"] = "nil" }
        withValue { $0["errors"] = "nil" }
        withValue { $0["did"] = 20 }
    }
    
    func testInitWithJson_IfJsonContainsWrongValues_SessionIsNil() {
        withValue { $0["sid"] = "" }
        withValue { $0["started"] = "20" }
        withValue { $0["status"] = "20" }
    }
    
    func withValue(setValue: (inout [String: Any]) -> Void) {
        let expected = SentrySession(releaseName: "release")
        var serialized = expected.serialize()
        setValue(&serialized)
        XCTAssertNil(SentrySession(jsonObject: serialized))
    }
    
    func testSerialize_Bools() {
        let session = SentrySession(releaseName: "")

        var json = session.serialize()
        json["init"] = 2
        
        let session2 = SentrySession(jsonObject: json)
        
        let result = session2!.serialize() 
        
        XCTAssertTrue(result["init"] as? Bool ?? false)
        XCTAssertNotEqual(2, result["init"] as? NSNumber ?? 2)
        
    }
}

extension SentrySessionStatus {
    var description: String {
        return nameForSentrySessionStatus(self)
    }
}
