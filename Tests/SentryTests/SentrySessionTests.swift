import SentryTestUtils
import XCTest

class SentrySessionTestsSwift: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    
    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testEndSession() {
        let session = SentrySession(releaseName: "0.1.0", distinctId: "some-id")
        let date = currentDateProvider.date().addingTimeInterval(1)
        session.endExited(withTimestamp: date)
        
        XCTAssertEqual(1, session.duration)
        XCTAssertEqual(date, session.timestamp)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
    }
    
    func testInitAndDurationNilWhenSerialize() {
        let session1 = SentrySession(releaseName: "1.4.0", distinctId: "some-id")
        var json = session1.serialize()
        json.removeValue(forKey: "init")
        json.removeValue(forKey: "duration")
        
        let date = currentDateProvider.date().addingTimeInterval(2)
        json["timestamp"] = sentry_toIso8601String(date as Date)
        guard let session = SentrySession(jsonObject: json) else {
            XCTFail("Couldn't create session from JSON"); return
        }
        
        let sessionSerialized = session.serialize()
        let duration = sessionSerialized["duration"] as? Double ?? -1
        XCTAssertEqual(2, duration)
    }

    func testCopySession() throws {
        let user = User()
        user.email = "someone@sentry.io"

        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.user = user
        session.abnormalMechanism = "app hang"
        let copiedSession = try XCTUnwrap(session.copy() as? SentrySession)

        XCTAssertEqual(session, copiedSession)
        XCTAssertEqual(session.abnormalMechanism, copiedSession.abnormalMechanism)

        // The user is copied as well
        session.user?.email = "someone_else@sentry.io"
        XCTAssertNotEqual(session, copiedSession)
    }
    
    func testInitWithJson_Status_MapsToCorrectStatus() throws {
        func testStatus(status: SentrySessionStatus, statusAsString: String) {
            let expected = SentrySession(releaseName: "release", distinctId: "some-id")
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
    
    private func withValue(setValue: (inout [String: Any]) -> Void) {
        let expected = SentrySession(releaseName: "release", distinctId: "some-id")
        var serialized = expected.serialize()
        setValue(&serialized)
        XCTAssertNil(SentrySession(jsonObject: serialized))
    }
    
    func testSerialize_Bools() throws {
        let session = SentrySession(releaseName: "", distinctId: "some-id")

        var json = session.serialize()
        json["init"] = 2
        
        let session2 = try XCTUnwrap(SentrySession(jsonObject: json))
        
        let result = session2.serialize() 
        
        XCTAssertTrue(result["init"] as? Bool ?? false)
        XCTAssertNotEqual(2, result["init"] as? NSNumber ?? 2)
    }
    
    func testSerializeAbormalMechanism() {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "distinctId")
        session.abnormalMechanism = "app hang"
        
        // Act
        let jsonDict = session.serialize()
        
        // Assert
        XCTAssertEqual(session.abnormalMechanism, jsonDict["abnormal_mechanism"] as? String)
    }
    
    func testSerializeAbormalMechanism_IfNil_NotAddedToDict() {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "distinctId")
        
        // Act
        let jsonDict = session.serialize()
        
        // Assert
        XCTAssertNil(jsonDict["abnormal_mechanism"])
    }
    
    func testInitWithJson_AbnormalMechanism_SetsAbnormalMechanism() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "distinctId")
        session.abnormalMechanism = "app hang"
        let jsonDict = session.serialize()
        
        // Act
        let actual = try XCTUnwrap(SentrySession(jsonObject: jsonDict))
        
        // Assert
        XCTAssertEqual(session.abnormalMechanism, actual.abnormalMechanism)
    }
    
    func testInitWithJson_AbnormalMechanismIsInt_DoesNotSetAbnormalMechanism() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "distinctId")
        session.abnormalMechanism = "app hang"
        var jsonDict = session.serialize()
        jsonDict["abnormal_mechanism"] = 1
        
        // Act
        let actual = try XCTUnwrap(SentrySession(jsonObject: jsonDict))
        
        // Assert
        XCTAssertNil(actual.abnormalMechanism)
    }
}

extension SentrySessionStatus {
    var description: String {
        return nameForSentrySessionStatus(self)
    }
}
