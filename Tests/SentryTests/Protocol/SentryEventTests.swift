@testable import Sentry
import SentryTestUtils
import XCTest

class SentryEventTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testInitWithLevel() {
        let dateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
        
        let event = Event(level: .debug)
        
        XCTAssertEqual(event.platform, "cocoa")
        XCTAssertEqual(event.level, .debug)
        XCTAssertEqual(event.timestamp, dateProvider.date())
    }
    
    func testSerialize() {
        let event = TestData.event
        let actual = event.serialize()
        
        // Changing the original doesn't modify the serialized
        event.fingerprint?.append("hello")
        event.modules?["this"] = "that"
        event.breadcrumbs?.append(TestData.crumb)
        event.context?["a"] = ["a": 0]

        XCTAssertEqual(event.eventId.sentryIdString, actual["event_id"] as? String)
        XCTAssertEqual(TestData.timestamp.timeIntervalSince1970, actual["timestamp"] as? TimeInterval)
        XCTAssertEqual("cocoa", actual["platform"] as? String)
        XCTAssertEqual("info", actual["level"] as? String)

        let expected = TestData.event

        // simple properties
        XCTAssertEqual(TestData.sdk, actual["sdk"] as? [String: String])
        XCTAssertEqual(expected.releaseName, actual["release"] as? String)
        XCTAssertEqual(expected.dist, actual["dist"] as? String)
        XCTAssertEqual(expected.environment, actual["environment"] as? String)
        XCTAssertEqual(expected.transaction, actual["transaction"] as? String)
        XCTAssertEqual(expected.fingerprint, actual["fingerprint"] as? [String])
        XCTAssertNotNil(actual["user"] as? [String: Any])
        XCTAssertEqual(TestData.event.modules, actual["modules"] as? [String: String])
        XCTAssertNotNil(actual["stacktrace"] as? [String: Any])
        XCTAssertNotNil(actual["request"] as? [String: Any])
        
        let crumbs = actual["breadcrumbs"] as? [[String: Any]]
        XCTAssertNotNil(crumbs)
        XCTAssertEqual(1, crumbs?.count)
        
        let context = actual["contexts"] as? [String: [String: Any]]
        XCTAssertEqual(context?.count, 1)
        XCTAssertEqual(context?["context"]?.count, 2)
        XCTAssertEqual(try XCTUnwrap(context?["context"]?["c"] as? String), "a")
        XCTAssertEqual(try XCTUnwrap(context?["context"]?["date"] as? String), "1970-01-01T00:00:10.000Z")
        
        XCTAssertNotNil(actual["message"] as? [String: Any])
        
        XCTAssertEqual(expected.logger, actual["logger"] as? String)
        XCTAssertEqual(expected.serverName, actual["server_name"] as? String)
        XCTAssertEqual(expected.type, actual["type"] as? String)
    }
    
    func testSerializeWithTypeTransaction() {
        let event = TestData.event
        event.type = "transaction"
        
        let actual = event.serialize()
        XCTAssertEqual(TestData.timestamp.timeIntervalSince1970, actual["start_timestamp"] as? TimeInterval)
    }
    
    func testSerializeWithTypeTransaction_WithoutStartTimestamp() {
        let event = TestData.event
        event.type = "transaction"
        event.startTimestamp = nil
        
        let actual = event.serialize()
        XCTAssertEqual(TestData.timestamp.timeIntervalSince1970, actual["start_timestamp"] as? TimeInterval
        )
    }
    
    func testSerializeWithoutBreadcrumbs() {
        let event = TestData.event
        event.breadcrumbs = nil
        
        let actual = event.serialize()
        XCTAssertNil(actual["breadcrumbs"])
    }
    
    func testInitWithError() {
        let error = CocoaError(CocoaError.coderInvalidValue)
        let event = Event(error: error)
        XCTAssertEqual(error, event.error as? CocoaError)
    }

    func testSerializeWithoutMessage() {
        let actual = Event().serialize()
        XCTAssertNil(actual["message"])
    }

    func testMessageIsNil() {
        XCTAssertNil(Event().message)
    }

    func testDecode_WithAllProperties() throws {
        // Arrange
        let event = TestData.event
        // Start timestamp is only serialized if event type is transaction
        event.type = "transaction"
        let actual = event.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryEventDecodable?)
        
        // Assert
        // We don't assert all properties of all objects because we have other tests for that.
        XCTAssertEqual(event.eventId, decoded.eventId)
        
        // Message
        let eventMessage = try XCTUnwrap(event.message)
        let decodedMessage = try XCTUnwrap(decoded.message)
        XCTAssertEqual(eventMessage.formatted, decodedMessage.formatted)
        XCTAssertEqual(eventMessage.message, decodedMessage.message)
        XCTAssertEqual(eventMessage.params, decodedMessage.params)
        
        XCTAssertEqual(event.timestamp, decoded.timestamp)
        XCTAssertEqual(event.startTimestamp, decoded.startTimestamp)
        XCTAssertEqual(event.level, decoded.level)
        
        XCTAssertEqual(event.platform, decoded.platform)
        XCTAssertEqual(event.logger, decoded.logger)
        XCTAssertEqual(event.serverName, decoded.serverName)
        XCTAssertEqual(event.releaseName, decoded.releaseName)
        XCTAssertEqual(event.dist, decoded.dist)
        XCTAssertEqual(event.environment, decoded.environment)
        XCTAssertEqual(event.transaction, decoded.transaction)
        XCTAssertEqual(event.type, decoded.type)
        
        XCTAssertEqual(event.tags, decoded.tags)

        let eventExtra = try XCTUnwrap(event.extra as? NSDictionary)
        let decodedExtra = try XCTUnwrap(decoded.extra as? NSDictionary)
        XCTAssertEqual(eventExtra, decodedExtra)
        
        let eventSdk = try XCTUnwrap(event.sdk as? NSDictionary)
        let decodedSdk = try XCTUnwrap(decoded.sdk as? NSDictionary)
        XCTAssertEqual(eventSdk, decodedSdk)

        let eventModules = try XCTUnwrap(event.modules as? NSDictionary)
        let decodedModules = try XCTUnwrap(decoded.modules as? NSDictionary)
        XCTAssertEqual(eventModules, decodedModules)

        XCTAssertEqual(event.fingerprint, decoded.fingerprint)
        
        XCTAssertEqual(event.user, decoded.user)

        let eventContext = try XCTUnwrap(event.context as? NSDictionary)
        let decodedContext = try XCTUnwrap(decoded.context as? NSDictionary)
        XCTAssertEqual(eventContext, decodedContext)

        // Threads
        let eventThreads = try XCTUnwrap(event.threads)
        let decodedThreads = try XCTUnwrap(decoded.threads)
        XCTAssertEqual(eventThreads.count, decodedThreads.count)
        let firstEventThread = try XCTUnwrap(eventThreads.first)
        let decodedFirstThread = try XCTUnwrap(decodedThreads.first)
        XCTAssertEqual(firstEventThread.name, decodedFirstThread.name)
        XCTAssertEqual(firstEventThread.crashed, decodedFirstThread.crashed)
        XCTAssertEqual(firstEventThread.current, decodedFirstThread.current)
        
        // Exceptions
        let eventExceptions = try XCTUnwrap(event.exceptions)
        let decodedExceptions = try XCTUnwrap(decoded.exceptions)
        XCTAssertEqual(eventExceptions.count, decodedExceptions.count)
        let firstEventException = try XCTUnwrap(eventExceptions.first)
        let decodedFirstException = try XCTUnwrap(decodedExceptions.first)
        XCTAssertEqual(firstEventException.type, decodedFirstException.type)
        XCTAssertEqual(firstEventException.value, decodedFirstException.value)
        
        // Exception Mechanism
        let firstEventExceptionMechanism = try XCTUnwrap(firstEventException.mechanism)
        let decodedFirstExceptionMechanism = try XCTUnwrap(decodedFirstException.mechanism)
        XCTAssertEqual(firstEventExceptionMechanism.type, decodedFirstExceptionMechanism.type)
        XCTAssertEqual(firstEventExceptionMechanism.desc, decodedFirstExceptionMechanism.desc)
        
        // Exception Mechanism Meta
        let firstEventExceptionMechanismMeta = try XCTUnwrap(firstEventExceptionMechanism.meta)
        let decodedFirstExceptionMechanismMeta = try XCTUnwrap(decodedFirstExceptionMechanism.meta)
        XCTAssertEqual(firstEventExceptionMechanismMeta.error?.code, decodedFirstExceptionMechanismMeta.error?.code)

        // Stacktrace
        let eventStacktrace = try XCTUnwrap(event.stacktrace)
        let decodedStacktrace = try XCTUnwrap(decoded.stacktrace)
        XCTAssertEqual(eventStacktrace.frames.count, decodedStacktrace.frames.count)

        // Stacktrace Frames
        let firstEventStacktraceFrame = try XCTUnwrap(eventStacktrace.frames.first)
        let decodedFirstStacktraceFrame = try XCTUnwrap(decodedStacktrace.frames.first)
        XCTAssertEqual(firstEventStacktraceFrame.fileName, decodedFirstStacktraceFrame.fileName)
        XCTAssertEqual(firstEventStacktraceFrame.symbolAddress, decodedFirstStacktraceFrame.symbolAddress)

        // Debug Meta
        let eventDebugMeta = try XCTUnwrap(event.debugMeta)
        let decodedDebugMeta = try XCTUnwrap(decoded.debugMeta)
        XCTAssertEqual(eventDebugMeta.count, decodedDebugMeta.count)

        // Debug Meta Frames
        let firstEventDebugMeta = try XCTUnwrap(eventDebugMeta.first)
        let decodedFirstDebugMeta = try XCTUnwrap(decodedDebugMeta.first)
        XCTAssertEqual(firstEventDebugMeta.type, decodedFirstDebugMeta.type)
        XCTAssertEqual(firstEventDebugMeta.imageAddress, decodedFirstDebugMeta.imageAddress)
        XCTAssertEqual(firstEventDebugMeta.imageSize, decodedFirstDebugMeta.imageSize)
        XCTAssertEqual(firstEventDebugMeta.type, decodedFirstDebugMeta.type)
        
        // Breadcrumbs
        let eventBreadcrumbs = try XCTUnwrap(event.breadcrumbs)
        let decodedBreadcrumbs = try XCTUnwrap(decoded.breadcrumbs)
        XCTAssertEqual(eventBreadcrumbs.count, decodedBreadcrumbs.count)
        let firstEventBreadcrumb = try XCTUnwrap(eventBreadcrumbs.first)
        let decodedFirstBreadcrumb = try XCTUnwrap(decodedBreadcrumbs.first)
        XCTAssertEqual(firstEventBreadcrumb.message, decodedFirstBreadcrumb.message)
        XCTAssertEqual(firstEventBreadcrumb.level, decodedFirstBreadcrumb.level)
        XCTAssertEqual(firstEventBreadcrumb.timestamp, decodedFirstBreadcrumb.timestamp)
        
        // Request
        let eventRequest = try XCTUnwrap(event.request)
        let decodedRequest = try XCTUnwrap(decoded.request)
        XCTAssertEqual(eventRequest.url, decodedRequest.url)
        XCTAssertEqual(eventRequest.method, decodedRequest.method)
        XCTAssertEqual(eventRequest.headers, decodedRequest.headers)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let event = Event()
        let actual = event.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryEventDecodable?)

        // Assert
        XCTAssertEqual(event.eventId, decoded.eventId)
        XCTAssertNil(decoded.message)
        XCTAssertNil(decoded.error)
        XCTAssertEqual(event.timestamp, decoded.timestamp)
        XCTAssertNil(decoded.startTimestamp)
        XCTAssertEqual(.none, decoded.level)
        XCTAssertEqual(event.platform, decoded.platform)
        XCTAssertNil(decoded.logger)
        XCTAssertNil(decoded.serverName)
        XCTAssertNil(decoded.releaseName)
        XCTAssertNil(decoded.dist)
        XCTAssertNil(decoded.environment)
        XCTAssertNil(decoded.transaction)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.tags)
        XCTAssertNil(decoded.extra)
        XCTAssertNil(decoded.sdk)
        XCTAssertNil(decoded.modules)
        XCTAssertNil(decoded.fingerprint)
        XCTAssertNil(decoded.user)
        XCTAssertNil(decoded.context)
        XCTAssertNil(decoded.threads)
        XCTAssertNil(decoded.exceptions)
        XCTAssertNil(decoded.stacktrace)
        XCTAssertNil(decoded.debugMeta)
        XCTAssertNil(decoded.breadcrumbs)
        XCTAssertNil(decoded.request)
    }
}
