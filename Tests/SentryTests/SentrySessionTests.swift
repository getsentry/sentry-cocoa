@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
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
        session.endNormally(withTimestamp: date)
        
        XCTAssertEqual(1, session.duration)
        XCTAssertEqual(date, session.timestamp)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
    }
    
    func testInitAndDurationNilWhenSerialize() {
        // A restored, still-active session (no init flag, no stored duration, but with a
        // timestamp) must not gain a duration on re-serialization. Duration is only set on
        // session end.
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
        XCTAssertNil(sessionSerialized["init"])
        XCTAssertNil(sessionSerialized["duration"])
    }

    func testSerialize_whenActiveSessionWithIncrementedErrors_shouldNotSerializeDuration() {
        // -- Arrange --
        // incrementErrors clears the init flag but does not set a timestamp. An active
        // (status ok) session must not report a bogus duration of 0 in this state.
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(60))
        session.incrementErrors()

        // -- Act --
        let json = session.serialize()

        // -- Assert --
        XCTAssertNil(json["duration"])
        XCTAssertNil(json["init"])
        XCTAssertEqual("ok", json["status"] as? String)
        XCTAssertEqual(1, json["errors"] as? UInt)
    }

    func testSerialize_whenActiveSession_shouldNotSerializeDuration() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")

        // -- Act --
        let json = session.serialize()

        // -- Assert --
        XCTAssertNil(json["duration"])
    }

    func testSerialize_whenEndedSession_shouldSerializeDuration() {
        // -- Arrange --
        // Duration is set when the session ends and must survive serialization.
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        let endDate = currentDateProvider.date().addingTimeInterval(2)
        session.endNormally(withTimestamp: endDate)

        // -- Act --
        let json = session.serialize()

        // -- Assert --
        XCTAssertEqual(2, json["duration"] as? Double)
        XCTAssertEqual("exited", json["status"] as? String)
    }

    func testCopySession() throws {
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.abnormalMechanism = "app hang"
        let copiedSession = try XCTUnwrap(session.copy() as? SentrySession)

        XCTAssertTrue(session.isEqual(to: copiedSession))
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
        testStatus(status: SentrySessionStatus.unhandled, statusAsString: "unhandled")
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
        expected.endNormally(withTimestamp: timestamp)
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
        expected.endNormally(withTimestamp: Date())
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
        session.endNormally(withTimestamp: Date())
        XCTAssertEqual(0, session.errors)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
        XCTAssertEqual(2, session.sequence)
    }

    // MARK: - Pending Unhandled

    func testInitDefaultValues_whenNewSession_shouldNotBePendingUnhandled() {
        // -- Arrange & Act --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")

        // -- Assert --
        XCTAssertFalse(session.pendingUnhandled)
    }

    func testMarkPendingUnhandled_shouldKeepStatusOkAndNotChangeSequenceOrErrors() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")

        // -- Act --
        session.markPendingUnhandled()

        // -- Assert --
        XCTAssertTrue(session.pendingUnhandled)
        XCTAssertEqual(SentrySessionStatus.ok, session.status)
        XCTAssertEqual(1, session.sequence)
        XCTAssertEqual(0, session.errors)
        XCTAssertTrue(session.flagInit?.boolValue ?? false)
    }

    func testMarkPendingUnhandled_whenCalledTwice_shouldStayPending() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")

        // -- Act --
        session.markPendingUnhandled()
        session.markPendingUnhandled()

        // -- Assert --
        XCTAssertTrue(session.pendingUnhandled)
        XCTAssertEqual(1, session.sequence)
    }

    func testEndNormally_whenPendingUnhandled_shouldEndAsUnhandled() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.incrementErrors()
        session.markPendingUnhandled()
        let timestamp = currentDateProvider.date().addingTimeInterval(3)

        // -- Act --
        session.endNormally(withTimestamp: timestamp)

        // -- Assert --
        XCTAssertEqual(SentrySessionStatus.unhandled, session.status)
        XCTAssertEqual(timestamp, session.timestamp)
        XCTAssertEqual(3, session.duration)
        XCTAssertEqual(1, session.errors)
    }

    func testEndCrashed_whenPendingUnhandled_shouldEndAsCrashed() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()

        // -- Act --
        session.endCrashed(withTimestamp: currentDateProvider.date())

        // -- Assert --
        XCTAssertEqual(SentrySessionStatus.crashed, session.status)
    }

    func testEndAbnormal_whenPendingUnhandled_shouldEndAsAbnormal() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()

        // -- Act --
        session.endAbnormal(withTimestamp: currentDateProvider.date())

        // -- Assert --
        XCTAssertEqual(SentrySessionStatus.abnormal, session.status)
    }

    func testCopy_whenPendingUnhandled_shouldCopyPendingUnhandled() throws {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()

        // -- Act --
        let copiedSession = try XCTUnwrap(session.copy() as? SentrySession)

        // -- Assert --
        XCTAssertTrue(copiedSession.pendingUnhandled)
    }

    func testSerialize_whenPendingUnhandled_shouldNotAddPendingUnhandled() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()

        // -- Act --
        let jsonDict = session.serialize()

        // -- Assert --
        XCTAssertNil(jsonDict["pending_unhandled"])
    }

    func testSerializeForPersistence_whenPendingUnhandled_shouldAddPendingUnhandled() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()

        // -- Act --
        let jsonDict = session.serializeForPersistence()

        // -- Assert --
        XCTAssertEqual(true, jsonDict["pending_unhandled"] as? Bool)
    }

    func testSerializeForPersistence_whenNotPendingUnhandled_shouldNotAddPendingUnhandled() {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")

        // -- Act --
        let jsonDict = session.serializeForPersistence()

        // -- Assert --
        XCTAssertNil(jsonDict["pending_unhandled"])
    }

    func testInitWithJson_whenPendingUnhandled_shouldSetPendingUnhandled() throws {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()
        let jsonDict = session.serializeForPersistence()

        // -- Act --
        let actual = try XCTUnwrap(SentrySession(jsonObject: jsonDict))

        // -- Assert --
        XCTAssertTrue(actual.pendingUnhandled)
    }

    func testInitWithJson_whenPendingUnhandledMissing_shouldNotBePendingUnhandled() throws {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        let jsonDict = session.serialize()

        // -- Act --
        let actual = try XCTUnwrap(SentrySession(jsonObject: jsonDict))

        // -- Assert --
        XCTAssertFalse(actual.pendingUnhandled)
    }

    func testInitWithJson_whenPendingUnhandledIsString_shouldNotBePendingUnhandled() throws {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        var jsonDict = session.serialize()
        jsonDict["pending_unhandled"] = "true"

        // -- Act --
        let actual = try XCTUnwrap(SentrySession(jsonObject: jsonDict))

        // -- Assert --
        XCTAssertFalse(actual.pendingUnhandled)
    }

    func testInitWithJson_whenPendingUnhandledAndEndNormally_shouldEndAsUnhandled() throws {
        // -- Arrange --
        let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        session.markPendingUnhandled()
        let restored = try XCTUnwrap(SentrySession(jsonObject: session.serializeForPersistence()))

        // -- Act --
        restored.endNormally(withTimestamp: currentDateProvider.date())

        // -- Assert --
        XCTAssertEqual(SentrySessionStatus.unhandled, restored.status)
    }
}

extension SentrySession {
    public func isEqual(to session: SentrySession) -> Bool {
        if sessionId != session.sessionId
            || started != session.started
            || status != session.status
            || errors != session.errors
            || sequence != session.sequence
            || distinctId != session.distinctId
            || timestamp != session.timestamp
            || duration != session.duration
            || releaseName != session.releaseName
            || environment != session.environment
            || flagInit != session.flagInit
            || pendingUnhandled != session.pendingUnhandled {
            return false
        }
        return true
    }
}
