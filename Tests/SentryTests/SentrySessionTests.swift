@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.abnormalMechanism = "app hang"
        let copiedSession = try XCTUnwrap(session.copy() as? SentrySession)

        XCTAssertEqual(session, copiedSession)
        XCTAssertEqual(session.abnormalMechanism, copiedSession.abnormalMechanism)
    }
    
    func testInitWithJson_Status_MapsToCorrectStatus() {
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

    func testInitDefaultValues() {
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        XCTAssertNotNil(session.sessionId)
        XCTAssertEqual(1, session.sequence)
        XCTAssertEqual(0, session.errors)
        XCTAssertTrue(session.flagInit?.boolValue ?? false)
        XCTAssertNotNil(session.started)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        XCTAssertNotNil(session.distinctId)

        XCTAssertNil(session.timestamp)
        XCTAssertEqual("1.0.0", session.releaseName)
        XCTAssertNil(session.environment)
        XCTAssertNil(session.duration)
    }

    func testSerializeDefaultValues() throws {
        let expected = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        let json = expected.serialize()
        let actual = try XCTUnwrap(SentrySession(jsonObject: json))

        XCTAssertEqual(expected.sessionId, actual.sessionId)
        XCTAssertEqual(expected.sequence, actual.sequence)
        XCTAssertEqual(expected.errors, actual.errors)

        XCTAssertEqual(expected.started.timeIntervalSinceReferenceDate, actual.started.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(expected.status, actual.status)
        XCTAssertEqual(expected.distinctId, actual.distinctId)
        XCTAssertNil(expected.timestamp)
        // Serialize session always have a timestamp (time of serialization)
        XCTAssertNotNil(actual.timestamp)
        XCTAssertEqual("1.0.0", expected.releaseName)
        XCTAssertEqual("1.0.0", actual.releaseName)
        XCTAssertNil(expected.environment)
        XCTAssertNil(actual.environment)
        XCTAssertNil(expected.duration)
        XCTAssertNil(actual.duration)
    }

    func testSerializeExtraFieldsEndedSessionWithNilStatus() throws {
        let expected = SentrySession(releaseName: "io.sentry@5.0.0-test", distinctId: "some-id")
        let timestamp = Date()
        expected.endExited(withTimestamp: timestamp)
        expected.environment = "prod"
        let json = expected.serialize()
        let actual = try XCTUnwrap(SentrySession(jsonObject: json))

        XCTAssertEqual(expected.sessionId, actual.sessionId)
        XCTAssertEqual(expected.sequence, actual.sequence)
        XCTAssertEqual(expected.errors, actual.errors)

        XCTAssertEqual(expected.started.timeIntervalSinceReferenceDate, actual.started.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(timestamp.timeIntervalSinceReferenceDate, expected.timestamp!.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(expected.timestamp!.timeIntervalSinceReferenceDate, actual.timestamp!.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(expected.status, actual.status)
        XCTAssertEqual(expected.distinctId, actual.distinctId)
        XCTAssertEqual(expected.releaseName, actual.releaseName)
        XCTAssertEqual(expected.environment, actual.environment)
        XCTAssertEqual(expected.duration, actual.duration)
    }

    func testSerializeErrorIncremented() throws {
        let expected = SentrySession(releaseName: "", distinctId: "some-id")
        expected.incrementErrors()
        expected.endExited(withTimestamp: Date())
        let json = expected.serialize()
        let actual = try XCTUnwrap(SentrySession(jsonObject: json))

        XCTAssertEqual(expected.sessionId, actual.sessionId)
        XCTAssertEqual(expected.sequence, actual.sequence)
        XCTAssertEqual(expected.errors, actual.errors)

        XCTAssertEqual(expected.started.timeIntervalSinceReferenceDate, actual.started.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(expected.timestamp!.timeIntervalSinceReferenceDate, actual.timestamp!.timeIntervalSinceReferenceDate, accuracy: 1)
        XCTAssertEqual(expected.status, actual.status)
        XCTAssertEqual(expected.distinctId, actual.distinctId)
        XCTAssertEqual(expected.releaseName, actual.releaseName)
        XCTAssertEqual(expected.environment, actual.environment)
        XCTAssertEqual(expected.duration, actual.duration)
    }

    func testAbnormalSession() {
        let session = SentrySession(releaseName: "", distinctId: "some-id")
        XCTAssertEqual(0, session.errors)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        XCTAssertEqual(1, session.sequence)
        session.incrementErrors()
        XCTAssertEqual(1, session.errors)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        XCTAssertEqual(2, session.sequence)
        session.endAbnormal(withTimestamp: Date())
        XCTAssertEqual(1, session.errors)
        XCTAssertEqual(SentrySessionStatus.abnormal, session.status)
        XCTAssertEqual(3, session.sequence)
    }

    func testCrashedSession() {
        let session = SentrySession(releaseName: "", distinctId: "some-id")
        XCTAssertEqual(1, session.sequence)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        session.endCrashed(withTimestamp: Date())
        XCTAssertEqual(SentrySessionStatus.crashed, session.status)
        XCTAssertEqual(2, session.sequence)
    }

    func testExitedSession() {
        let session = SentrySession(releaseName: "", distinctId: "some-id")
        XCTAssertEqual(0, session.errors)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        XCTAssertEqual(1, session.sequence)
        session.endExited(withTimestamp: Date())
        XCTAssertEqual(0, session.errors)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
        XCTAssertEqual(2, session.sequence)
    }
}

extension SentrySessionStatus {
    var description: String {
        return nameForSentrySessionStatus(self.rawValue)
    }
}
