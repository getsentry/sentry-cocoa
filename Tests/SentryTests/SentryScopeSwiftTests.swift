// swiftlint:disable file_length
@_spi(Private) import Sentry
import SentryTestUtils
import XCTest

class SentryScopeSwiftTests: XCTestCase {

    private class Fixture {
        let user: User
        let breadcrumb: Breadcrumb
        let scope: Scope
        let date: Date
        let event: Event
        let transaction: Span
        
        let dist = "dist"
        let environment = "environment"
        let fingerprint = ["fingerprint"]
        let context = ["context": ["c": "a"]]
        let tags = ["key": "value"]
        let extra = ["key": "value"]
        let level = SentryLevel.info
        let ipAddress = "127.0.0.1"
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        let maxBreadcrumbs = 5

        init() {
            date = Date(timeIntervalSince1970: 10)
            
            user = User(userId: "id")
            user.email = "user@sentry.io"
            user.username = "user123"
            user.ipAddress = "127.0.0.1"
            user.name = "User"
            user.ipAddress = ipAddress
            
            let geo = Geo()
            geo.city = "Vienna"
            geo.countryCode = "at"
            geo.region = "Vienna"
            user.geo = geo
            user.data = ["some": ["data": "data", "date": date] as [String: Any]]

            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = date
            breadcrumb.type = "user"
            breadcrumb.message = "Clicked something"
            breadcrumb.data = ["some": ["data": "data", "date": date] as [String: Any]]
            
            scope = Scope(maxBreadcrumbs: maxBreadcrumbs)
            scope.setUser(user)
            scope.setTag(value: tags["key"] ?? "", key: "key")
            scope.setExtra(value: extra["key"] ?? "", key: "key")
            scope.setDist(dist)

            scope.setEnvironment(environment)
            scope.setFingerprint(fingerprint)

            scope.setContext(value: context["context"] ?? ["": ""], key: "context")
            scope.setLevel(level)
            scope.addBreadcrumb(breadcrumb)
            
            scope.addAttachment(TestData.fileAttachment)
            
            scope.setAttribute(value: "my-value", key: "my-attribute-key")
            
            event = Event()
            event.message = SentryMessage(formatted: "message")
            
            transaction = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: transactionOperation), hub: nil)
        }
        
        var observer: TestScopeObserver {
            return TestScopeObserver()
        }
        
        var dateAs8601String: String {
            sentry_toIso8601String(date as Date)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testSerialize() throws {
        let scope = fixture.scope
        let actual = scope.serialize()
        
        // Changing the original doesn't modify the serialized
        scope.setTag(value: "another", key: "another")
        scope.setExtra(value: "another", key: "another")
        scope.setContext(value: ["": 1], key: "another")
        scope.setUser(User())
        scope.setDist("")
        scope.setEnvironment("")
        scope.setFingerprint([])
        scope.setLevel(SentryLevel.debug)
        scope.clearBreadcrumbs()
        scope.addAttachment(TestData.fileAttachment)
        scope.span = fixture.transaction
        
        XCTAssertEqual(["key": "value"], actual["tags"] as? [String: String])
        XCTAssertEqual(["key": "value"], actual["extra"] as? [String: String])
        
        XCTAssertEqual(fixture.context, actual["context"] as? [String: [String: String]])
        
        let propagationContext = fixture.scope.propagationContext
        XCTAssertEqual(["span_id": propagationContext.spanId.sentrySpanIdString, "trace_id": propagationContext.traceId.sentryIdString], actual["traceContext"] as? [String: String])
        
        let actualUser = actual["user"] as? [String: Any]
        XCTAssertEqual(fixture.ipAddress, actualUser?["ip_address"] as? String)
        
        XCTAssertEqual("dist", actual["dist"] as? String)
        XCTAssertEqual(fixture.environment, actual["environment"] as? String)
        XCTAssertEqual(fixture.fingerprint, actual["fingerprint"] as? [String])
        XCTAssertEqual("info", actual["level"] as? String)
        XCTAssertNil(actual["transaction"])
        XCTAssertNotNil(actual["breadcrumbs"])
    }

    func testInitWithScope() throws {
        let scope = fixture.scope
        scope.span = fixture.transaction

        let snapshot = try XCTUnwrap(scope.serialize() as? [String: AnyHashable])

        let cloned = Scope(scope: scope)
        XCTAssertEqual(try XCTUnwrap(cloned.serialize() as? [String: AnyHashable]), snapshot)
        XCTAssertEqual(scope.propagationContext.spanId, cloned.propagationContext.spanId)
        XCTAssertEqual(scope.propagationContext.traceId, cloned.propagationContext.traceId)
        XCTAssertEqual(scope.attributes as NSDictionary, cloned.attributes as NSDictionary)

        let (event1, event2) = (Event(), Event())
        (event1.timestamp, event2.timestamp) = (fixture.date, fixture.date)
        event2.eventId = event1.eventId
        scope.applyTo(event: event1, maxBreadcrumbs: 10)
        cloned.applyTo(event: event2, maxBreadcrumbs: 10)
        XCTAssertEqual(
            try XCTUnwrap(event1.serialize() as? [String: AnyHashable]),
            try XCTUnwrap(event2.serialize() as? [String: AnyHashable])
        )

        cloned.setExtras(["aa": "b"])
        cloned.setTags(["ab": "c"])
        cloned.addBreadcrumb(Breadcrumb(level: .debug, category: "http2"))
        cloned.setUser(User(userId: "aid"))
        cloned.setContext(value: ["ae": "af"], key: "myContext")
        cloned.setDist("a456")
        cloned.setEnvironment("a789")

        XCTAssertEqual(try XCTUnwrap(scope.serialize() as? [String: AnyHashable]), snapshot)
        XCTAssertNotEqual(try XCTUnwrap(scope.serialize() as? [String: AnyHashable]), try XCTUnwrap(cloned.serialize() as? [String: AnyHashable]))
    }

    func testApplyToEvent() {
        let actual = fixture.scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        let actualContext = actual?.context as? [String: [String: String]]

        XCTAssertEqual(fixture.tags, actual?.tags)
        XCTAssertEqual(fixture.extra, actual?.extra as? [String: String])
        XCTAssertEqual(fixture.user, actual?.user)
        XCTAssertEqual(fixture.dist, actual?.dist)
        XCTAssertEqual(fixture.environment, actual?.environment)
        XCTAssertEqual(fixture.fingerprint, actual?.fingerprint)
        XCTAssertEqual(fixture.level, actual?.level)
        XCTAssertEqual([fixture.breadcrumb], actual?.breadcrumbs)
        XCTAssertEqual(fixture.context["c"], actualContext?["c"])
        XCTAssertNotNil(actualContext?["trace"])
    }
    
    func testApplyToEvent_EventWithTags() {
        let tags = NSMutableDictionary(dictionary: ["my": "tag"])
        let event = fixture.event
        event.tags = tags as? [String: String]
        
        let actual = fixture.scope.applyTo(event: event, maxBreadcrumbs: 10)
        
        tags.addEntries(from: fixture.tags)
        XCTAssertEqual(tags as? [String: String], actual?.tags)
    }
    
    func testApplyToEvent_EventWithExtra() {
        let extra = NSMutableDictionary(dictionary: ["my": "extra"])
        let event = fixture.event
        event.extra = extra as? [String: String]
        
        let actual = fixture.scope.applyTo(event: event, maxBreadcrumbs: 10)
        
        extra.addEntries(from: fixture.extra)
        XCTAssertEqual(extra as? [String: String], actual?.extra as? [String: String])
    }
    
    func testApplyToEvent_ScopeWithoutUser() {
        let scope = fixture.scope
        scope.setUser(nil)
        
        let event = fixture.event
        event.user = fixture.user
        
        let actual = scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        
        XCTAssertEqual(fixture.user, actual?.user)
    }
    
    func testApplyToEvent_ScopeWithoutDist() {
        let scope = fixture.scope
        scope.setDist(nil)
        
        let event = fixture.event
        event.dist = "myDist"
        
        let actual = scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        
        XCTAssertEqual(event.dist, actual?.dist)
    }
    
    func testApplyToEvent_ScopeWithSpan() throws {
        let scope = fixture.scope
        scope.span = fixture.transaction
        
        let actual = scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        let trace = try XCTUnwrap(fixture.event.context?["trace"])

        XCTAssertEqual(actual?.transaction, fixture.transactionName)
        XCTAssertEqual(trace["op"] as? String, fixture.transactionOperation)
        XCTAssertEqual(trace["trace_id"] as? String, fixture.transaction.traceId.sentryIdString)
        XCTAssertEqual(trace["span_id"] as? String, fixture.transaction.spanId.sentrySpanIdString)
        XCTAssertEqual(trace["status"] as? String, "ok")
    }
    
    func testApplyToEvent_EventWithDist() {
        let event = fixture.event
        event.dist = "myDist"
        
        let actual = fixture.scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        
        XCTAssertEqual(event.dist, actual?.dist)
    }
    
    func testApplyToEvent_ScopeWithoutEnvironment() {
        let scope = fixture.scope
        scope.setEnvironment(nil)
        
        let event = fixture.event
        event.environment = "myEnvironment"
        
        let actual = scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        
        XCTAssertEqual(event.environment, actual?.environment)
    }
    
    func testApplyToEvent_EventWithEnvironment() {
        let event = fixture.event
        event.environment = "myEnvironment"
        
        let actual = fixture.scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        
        XCTAssertEqual(event.environment, actual?.environment)
    }

    func testApplyToEvent_ForFatalEvent_DoesNotApplyScope() {
        let event = fixture.event
        event.isFatalEvent = true

        let actual = fixture.scope.applyTo(event: fixture.event, maxBreadcrumbs: 10)

        XCTAssertNil(actual?.tags)
        XCTAssertNil(actual?.extra)
    }
    
    func testSpan_FromMultipleThreads() {
        let scope = fixture.scope
        
        testConcurrentModifications(asyncWorkItems: 20, writeLoopCount: 10, writeWork: { _ in
            
            scope.span = SentryTracer(transactionContext: TransactionContext(name: self.fixture.transactionName, operation: self.fixture.transactionOperation), hub: nil)
            
        }, readWork: {
            XCTAssertNotNil(scope.span)
        })
    }
    
    func testMaxBreadcrumbs_IsZero() {
        let scope = Scope(maxBreadcrumbs: 0)
        
        scope.addBreadcrumb(fixture.breadcrumb)
        
        let serialized = scope.serialize()
        XCTAssertNil(serialized["breadcrumbs"])
    }
    
    func testMaxBreadcrumbs_IsNegative() {
        let scope = Scope(maxBreadcrumbs: Int.min)
        
        scope.addBreadcrumb(fixture.breadcrumb)
        
        let serialized = scope.serialize()
        XCTAssertNil(serialized["breadcrumbs"])
    }
    
    func testApplyToEvent_EventWithContext() {
        let context = NSMutableDictionary(dictionary: ["my": ["extra": "context"],
                                                       "trace": fixture.scope.propagationContext.traceForEvent() ])
        let event = fixture.event
        event.context = context as? [String: [String: String]]
        
        let actual = fixture.scope.applyTo(event: event, maxBreadcrumbs: 10)
        
        context.addEntries(from: fixture.context)
        XCTAssertEqual(context as? [String: [String: String]],
                       actual?.context as? [String: [String: String]])
    }

    func testApplyToEvent_EventWithError_contextHasTrace() {
        let event = fixture.event
        event.exceptions = [Exception(value: "Error", type: "Exception")]

        let actual = fixture.scope.applyTo(event: event, maxBreadcrumbs: 10)

        XCTAssertNotNil(actual?.context?["trace"])
    }
    
    func testApplyToEvent_EventWithContext_MergesContext() {
        let context = NSMutableDictionary(dictionary: [
            "first": ["a": "b", "c": "d"], "trace": fixture.scope.propagationContext.traceForEvent()])
        let event = fixture.event
        event.context = context as? [String: [String: String]]
        
        let expectedAppContext = [
            "first": [ "a": "b", "c": "d", "e": "f"],
            "second": ["0": "1" ]
        ]
        
        // The existing values from the scope get overwritten by the values of the event
        // "a": [12:1] will be overwritten with "a": "b"
        // "c": "c" will be overwritten with "c": "d"
        // "e": "f" gets added from the scope to the event
        let scope = fixture.scope
        scope.setContext(value: ["a": [12: 1], "c": "c", "e": "f"], key: "first")
        scope.setContext(value: ["0": "1"], key: "second")
        
        let actual = scope.applyTo(event: event, maxBreadcrumbs: 10)
        let actualContext = actual?.context as? [String: [String: String]]
        
        context.addEntries(from: fixture.context)
        context.addEntries(from: expectedAppContext)
        
        XCTAssertEqual(context as? [String: [String: String]],
                       actualContext)
    }
        
    func testClear() {
        let scope = fixture.scope
        scope.clear()
        
        let expected = Scope(maxBreadcrumbs: fixture.maxBreadcrumbs)
        XCTAssertEqual(expected, scope)
        XCTAssertEqual(0, scope.attachments.count)
        XCTAssertEqual(0, scope.attributes.count)
    }
    
    func testAttachmentsIsACopy() {
        let scope = fixture.scope
        
        let attachments = scope.attachments
        scope.addAttachment(TestData.fileAttachment)
        
        XCTAssertEqual(1, attachments.count)
    }
    
    func testClearAttachments() {
        let scope = fixture.scope
        scope.addAttachment(TestData.fileAttachment)
        
        scope.clearAttachments()
        
        XCTAssertEqual(0, scope.attachments.count)
    }
    
    // With this test we test if modifications from multiple threads don't lead to a crash.
    func testModifyingFromMultipleThreads() {
        let scope = fixture.scope
        
        // The number is kept small for the CI to not take too long.
        // If you really want to test this increase to 100_000 or so.
        testConcurrentModifications(asyncWorkItems: 2, writeLoopCount: 10, writeWork: { _ in
            
            let key = "key"
            
            _ = Scope(scope: scope)
            
            for _ in 0...100 {
                scope.addBreadcrumb(self.fixture.breadcrumb)
            }
            
            scope.serialize()
            scope.clearBreadcrumbs()
            scope.addBreadcrumb(self.fixture.breadcrumb)
            
            scope.applyTo(session: SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
            
            scope.setFingerprint(nil)
            scope.setFingerprint(["finger", "print"])
            
            scope.setContext(value: ["some": "value"], key: key)
            scope.removeContext(key: key)
            
            scope.setExtra(value: 1, key: key)
            scope.removeExtra(key: key)
            scope.setExtras(["value": "1", "value2": "2"])
            
            scope.applyTo(event: TestData.event, maxBreadcrumbs: 5)
            
            scope.setTag(value: "value", key: key)
            scope.removeTag(key: key)
            scope.setTags(["tag1": "hello", "tag2": "hello"])
            
            scope.addAttachment(TestData.fileAttachment)
            scope.clearAttachments()
            scope.addAttachment(TestData.fileAttachment)
            
            scope.span = SentryTracer(transactionContext: TransactionContext(name: self.fixture.transactionName, operation: self.fixture.transactionOperation), hub: nil)
            
            for _ in 0...10 {
                scope.addBreadcrumb(self.fixture.breadcrumb)
            }
            scope.serialize()
            
            scope.setUser(self.fixture.user)
            scope.setDist("dist")
            scope.setEnvironment("env")
            scope.setLevel(SentryLevel.debug)
            
            scope.applyTo(session: SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
            scope.applyTo(event: TestData.event, maxBreadcrumbs: 5)
            
            scope.serialize()
        })
    }
    
    func testScopeObserver_setUser() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let user = TestData.user
        sut.setUser(user)
        
        XCTAssertEqual(user, observer.user)
    }
    
    func testScopeObserver_setTags() {
        let sut = Scope()
        
        sut.setTags(fixture.tags)
        
        XCTAssertEqual(fixture.tags, sut.tags)
    }
    
    func testScopeObserver_setTagValue() {
        let sut = Scope()
        
        sut.setTag(value: "tag", key: "tag")
        
        XCTAssertEqual( ["tag": "tag"], sut.tags)
    }
    
    func testScopeObserver_removeTag() {
        let sut = Scope()
        
        sut.setTag(value: "tag", key: "tag")
        sut.removeTag(key: "tag")
        
        XCTAssertEqual(0, sut.tags.count)
    }
    
    func testScopeObserver_setExtras() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.setExtras( fixture.extra)
        
        XCTAssertEqual(fixture.extra, observer.extras as? [String: String])
    }
    
    func testScopeObserver_setExtraValue() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let extras = ["extra": 1]
        
        sut.setExtra(value: 1, key: "extra")
        XCTAssertEqual(extras, observer.extras as? [String: Int])
    }
    
    func testScopeObserver_removeExtra() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.setExtras(["extra": 1])
        sut.removeExtra(key: "extra")
        
        XCTAssertEqual(0, observer.extras?.count)
    }
    
    func testScopeObserver_setContext() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let value = ["extra": 1]
        sut.setContext(value: ["extra": 1], key: "context")
        
        XCTAssertEqual(["context": value], observer.context as? [String: [String: Int]])
    }
    
    func testScopeObserver_setDist() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let dist = "dist"
        sut.setDist(dist)
        
        XCTAssertEqual(dist, observer.dist)
    }
    
    func testScopeObserver_setEnvironment() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let environment = "environment"
        sut.setEnvironment(environment)
        
        XCTAssertEqual(environment, observer.environment)
    }
    
    func testScopeObserver_setFingerprint() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let fingerprint = ["finger", "print"]
        sut.setFingerprint(fingerprint)
        
        XCTAssertEqual(fingerprint, observer.fingerprint)
    }
    
    func testScopeObserver_setLevel() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let level = SentryLevel.info
        sut.setLevel(level)
        
        XCTAssertEqual(level, observer.level)
    }
    
    func testScopeObserver_setAttributes() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.setAttribute(value: "my-attribute", key: "key-string")
        sut.setAttribute(value: false, key: "key-bool")
        sut.setAttribute(value: 1.5, key: "key-double")
        sut.setAttribute(value: 4, key: "key-integer")
        
        XCTAssertEqual([
            "key-string": "my-attribute",
            "key-bool": false,
            "key-double": 1.5,
            "key-integer": 4
        ] as [String: AnyHashable], try XCTUnwrap(sut.attributes as? [String: AnyHashable]))
    }
    
    func testScopeObserver_addBreadcrumb() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let crumb = TestData.crumb
        sut.addBreadcrumb(crumb)
        sut.addBreadcrumb(crumb)
        
        XCTAssertEqual(
            [
                try XCTUnwrap(crumb.serialize() as? [String: AnyHashable]),
                try XCTUnwrap(crumb.serialize() as? [String: AnyHashable])
            ],
            observer.crumbs
        )
    }
    
    func testScopeObserver_clearBreadcrumb() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.clearBreadcrumbs()
        sut.clearBreadcrumbs()
        
        XCTAssertEqual(2, observer.clearBreadcrumbInvocations)
    }
    
    func testScopeObserver_setSpan_SetsTraceContext() throws {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let transaction = fixture.transaction
        sut.span = transaction

        let traceContext = try XCTUnwrap(observer.traceContext)
        let serializedTransaction = transaction.serialize()

        var expectedKeys = Set(serializedTransaction.keys)
        // The transaction doesn't serialize the status when it's undefined, but the trace context sets it to OK.
        expectedKeys.insert("status")

        XCTAssertEqual(Set(traceContext.keys), expectedKeys)

        XCTAssertEqual(serializedTransaction["trace_id"] as? String, traceContext["trace_id"] as? String)
        XCTAssertEqual(serializedTransaction["span_id"] as? String, traceContext["span_id"] as? String)
        XCTAssertEqual(serializedTransaction["op"] as? String, traceContext["op"] as? String)
        XCTAssertEqual(serializedTransaction["origin"] as? String, traceContext["origin"] as? String)
        XCTAssertEqual(serializedTransaction["type"] as? String, traceContext["type"] as? String)
        XCTAssertEqual(serializedTransaction["start_timestamp"] as? Double, traceContext["start_timestamp"] as? Double)
        XCTAssertEqual(serializedTransaction["timestamp"] as? Double, traceContext["timestamp"] as? Double)
        XCTAssertEqual(traceContext["status"] as? String, "ok")
    }

    func testScopeObserver_setSpanToNil_SetsTraceContextToPropagationContext() throws {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.span = fixture.transaction
        sut.span = nil
        
        let traceContext = try XCTUnwrap(observer.traceContext)

        XCTAssertEqual(2, traceContext.count)
        XCTAssertEqual(sut.propagationContext.traceId.sentryIdString, traceContext["trace_id"] as? String)
        XCTAssertEqual(sut.propagationContext.spanId.sentrySpanIdString, traceContext["span_id"] as? String)
    }
    
    func testScopeObserver_clear() {
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        sut.clear()
        sut.clear()
        
        XCTAssertEqual(2, observer.clearInvocations)
    }
    
    func testDefaultBreadcrumbCapacity() {
        let scope = Scope()
        for i in 0..<197 {
            let crumb = Breadcrumb()
            crumb.message = "\(i)"
            scope.addBreadcrumb(crumb)
        }

        let scopeSerialized = scope.serialize()
        let scopeCrumbs = scopeSerialized["breadcrumbs"] as? [[String: Any]]
        XCTAssertEqual(100, scopeCrumbs?.count ?? 0)
        
        var j = 0
        for i in 97..<197 {
            let actualMessage = scopeCrumbs?[j]["message"] as? String
            XCTAssertEqual("\(i)", actualMessage)
            
            j += 1
        }
    }
    
    func testBreadcrumbsNotFull() {
        let scope = Scope()
        for i in 0..<97 {
            let crumb = Breadcrumb()
            crumb.message = "\(i)"
            scope.addBreadcrumb(crumb)
        }

        let scopeSerialized = scope.serialize()
        let scopeCrumbs = scopeSerialized["breadcrumbs"] as? [[String: Any]]
        XCTAssertEqual(97, scopeCrumbs?.count ?? 0)
        
        for i in 0..<97 {
            let actualMessage = scopeCrumbs?[i]["message"] as? String
            XCTAssertEqual("\(i)", actualMessage)
        }
    }
    
    func testClearBreadcrumb() {
        let scope = Scope()
        scope.clearBreadcrumbs()
        for _ in 0..<101 {
            scope.addBreadcrumb(fixture.breadcrumb)
        }
        scope.clearBreadcrumbs()
        
        let scopeSerialized = scope.serialize()
        
        let scopeCrumbs = scopeSerialized["breadcrumbs"] as? [[String: Any]]
        XCTAssertEqual(0, scopeCrumbs?.count ?? 0)
    }
    
    func testModifyScopeFromDifferentThreads() {
        let scope = Scope()
        scope.add(SentryCrashScopeHelper.getScopeObserver(withMaxBreacdrumb: 100))
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { i in
            let user = User()
            user.name = "name \(i)"
            scope.setUser(user)
        })
    }

    func testRemoveContextForKey_keyNotFound_shouldNotChangeContext() {
        // -- Arrange --
        let scope = Scope()
        scope.setContext(value: ["AA": 1], key: "A")
        scope.setContext(value: ["BB": "2"], key: "B")

        // -- Act --
        scope.removeContext(key: "C")

        // -- Assert --
        let actual = scope.serialize()["context"] as? NSDictionary
        let expected: NSDictionary = ["A": ["AA": 1], "B": ["BB": "2"]]
        XCTAssertEqual(actual, expected)
    }

    func testRemoveContextForKey_keyFound_shouldRemoveKeyValuePairFromContext() {
        // -- Arrange --
        let scope = Scope()
        scope.setContext(value: ["AA": 1], key: "A")
        scope.setContext(value: ["BB": "2"], key: "B")

        // -- Act --
        scope.removeContext(key: "B")

        // -- Assert --
        let actual = scope.serialize()["context"] as? NSDictionary
        let expected: NSDictionary = ["A": ["AA": 1]]
        XCTAssertEqual(actual, expected)
    }

    func testRemoveContextForKey_keyNotFound_shouldUpdateAllObserverContexts() {
        // -- Arrange --
        let scope = Scope()
        scope.setContext(value: ["AA": 1], key: "A")
        scope.setContext(value: ["BB": "2"], key: "B")

        let observer1 = TestScopeObserver()
        scope.add(observer1)
        let observer2 = TestScopeObserver()
        scope.add(observer2)

        // -- Act --
        scope.removeContext(key: "C")

        // -- Assert --
        let expected: NSDictionary = ["A": ["AA": 1], "B": ["BB": "2"]]
        XCTAssertEqual(observer1.context as? NSDictionary, expected)
        XCTAssertEqual(observer2.context as? NSDictionary, expected)
    }

    func testRemoveContextForKey_keyFound_shouldUpdateAllObserverContexts() {
        // -- Arrange --
        let scope = Scope()
        scope.setContext(value: ["AA": 1], key: "A")
        scope.setContext(value: ["BB": "2"], key: "B")

        let observer1 = TestScopeObserver()
        scope.add(observer1)
        let observer2 = TestScopeObserver()
        scope.add(observer2)

        // -- Act --
        scope.removeContext(key: "B")

        // -- Assert --
        let expected: NSDictionary = ["A": ["AA": 1]]
        XCTAssertEqual(observer1.context as? NSDictionary, expected)
        XCTAssertEqual(observer2.context as? NSDictionary, expected)
    }

    func testScopeObserver_setPropagationContext_UpdatesTraceContext() throws {
        // -- Arrange --
        let sut = Scope()
        let observer = fixture.observer
        sut.add(observer)
        
        let traceId = SentryId(uuidString: "12345678123456781234567812345678")
        let spanId = SpanId(value: "1234567812345678")
        let propagationContext = SentryPropagationContext(trace: traceId, spanId: spanId)
        
        // -- Act --
        sut.propagationContext = propagationContext
        
        // -- Assert -- 
        let traceContext = try XCTUnwrap(observer.traceContext)
        XCTAssertEqual(2, traceContext.count)
        XCTAssertEqual(traceId.sentryIdString, traceContext["trace_id"] as? String)
        XCTAssertEqual(spanId.sentrySpanIdString, traceContext["span_id"] as? String)
    }

    func testGetCasedInternalSpan_SpanIsNil() {
        // -- Arrange --
        let scope = Scope()

        // -- Act --
        let span = scope.getCastedInternalSpan()

        // -- Assert --
        XCTAssertNil(span)
    }

#if os(macOS)
    // We test this only on macOS because the SentrySpan init methods require a frames tracker.
    // As we're testing simple logic here, we can skip the other platforms.
    func testGetCasedInternalSpan_SpanIsOfInternalTypeSpan() throws {
        // -- Arrange --
        let scope = Scope()
        let span = SentrySpan(context: SpanContext(operation: "TEST"))

        scope.span = span

        // -- Act --
        let actualSpan = try XCTUnwrap(scope.getCastedInternalSpan())

        // -- Assert --
        XCTAssertEqual(actualSpan, span)
        XCTAssertEqual(actualSpan.spanId, span.spanId)
    }

    func testGetCasedInternalSpan_SpanIsSubClassOfInternalTypeSpan() throws {
        // -- Arrange --
        let scope = Scope()
        let span = SubClassOfSentrySpan(context: SpanContext(operation: "TEST"))

        scope.span = span

        // -- Act --
        let actualSpan = try XCTUnwrap(scope.getCastedInternalSpan())

        // -- Assert --
        XCTAssertEqual(actualSpan, span)
        XCTAssertEqual(actualSpan.spanId, span.spanId)
    }
#endif // os(macOS)

    func testGetCasedInternalSpan_SpanIsOfDifferentType() {
        // -- Arrange --
        let scope = Scope()
        let span = NotOfTypeSpan()

        scope.span = span

        // -- Act --
        let actualSpan = scope.getCastedInternalSpan()

        // -- Assert --
        XCTAssertNil(actualSpan)
    }
    
    func testSetStringAttribute() {
        let scope = Scope()
        
        scope.setAttribute(value: "test-string", key: "a-string-key")
        
        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-string-key"] as? String), "test-string")
    }
    
    func testSetStringAttributeAgainChangesValue() {
        let scope = Scope()
        
        scope.setAttribute(value: "test-string", key: "a-string-key")
        
        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-string-key"] as? String), "test-string")
        
        scope.setAttribute(value: "another-string", key: "a-string-key")
        
        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-string-key"] as? String), "another-string")
    }

    func testSetBoolAttribute() {
        let scope = Scope()
        
        scope.setAttribute(value: true, key: "a-bool-key")
        scope.setAttribute(value: false, key: "a-bool-key-false")

        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-bool-key-false"] as? Bool), false)
        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-bool-key"] as? Bool), true)
    }

    func testSetDoubleAttribute() {
        let scope = Scope()
        
        scope.setAttribute(value: 1.4728, key: "a-double-key")
        
        XCTAssertEqual(try XCTUnwrap(scope.attributes["a-double-key"] as? Double), 1.4728)
    }

    func testSetIntegerAttribute() {
        let scope = Scope()
        
        scope.setAttribute(value: 4, key: "an-integer-key")
        
        XCTAssertEqual(try XCTUnwrap(scope.attributes["an-integer-key"] as? Int), 4)
    }

    func testRemoveAttribute() {
        let scope = Scope()
        
        scope.setAttribute(value: "test-string", key: "a-key")
        
        scope.removeAttribute(key: "a-key")

        XCTAssertNil(scope.attributes["a-key"])
    }
    
    func testRemoveNotExistingAttributeDoesNotCrash() {
        let scope = Scope()
        
        // This should not crash
        scope.removeAttribute(key: "an-invalid-key")

        XCTAssertTrue(scope.attributes.isEmpty)
    }

    private class TestScopeObserver: NSObject, SentryScopeObserver {
        var tags: [String: String]?
        func setTags(_ tags: [String: String]?) {
            self.tags = tags
        }
        
        var extras: [String: Any]?
        func setExtras(_ extras: [String: Any]?) {
            self.extras = extras
        }
        
        var context: [String: [String: Any]]?
        func setContext(_ context: [String: [String: Any]]?) {
            self.context = context
        }
        
        var traceContext: [String: Any]?
        func setTraceContext(_ traceContext: [String: Any]?) {
            self.traceContext = traceContext
        }
        
        var dist: String?
        func setDist(_ dist: String?) {
            self.dist = dist
        }
        
        var environment: String?
        func setEnvironment(_ environment: String?) {
            self.environment = environment
        }
        
        var fingerprint: [String]?
        func setFingerprint(_ fingerprint: [String]?) {
            self.fingerprint = fingerprint
        }
        
        var level: SentryLevel?
        func setLevel(_ level: SentryLevel) {
            self.level = level
        }
        
        var crumbs: [[String: AnyHashable]] = []
        func addSerializedBreadcrumb(_ crumb: [String: Any]) {
            guard let typedCrumb = crumb as? [String: AnyHashable] else {
                return
            }
            crumbs.append(typedCrumb)
        }

        var clearBreadcrumbInvocations = 0
        func clearBreadcrumbs() {
            clearBreadcrumbInvocations += 1
        }
        
        var clearInvocations = 0
        func clear() {
            clearInvocations += 1
        }
        
        var user: User?
        func setUser(_ user: User?) {
            self.user = user
        }
        
        var attributes: [String: Any]?
        func setAttributes(_ attributes: [String: Any]?) {
            self.attributes = attributes
        }
    }
}

// A minimal dummy Span implementation that is not SentrySpan.
private final class NotOfTypeSpan: NSObject, Span {

    init(traceId: SentryId = SentryId()) {
        self.traceId = traceId
    }

    // MARK: - Properties required by Span (set to neutral values)
    var traceId: SentryId = SentryId()
    var spanId: SpanId = SpanId()
    var parentSpanId: SpanId?
    var sampled: SentrySampleDecision = .undecided
    var operation: String = ""
    var origin: String = ""
    var spanDescription: String?
    var status: SentrySpanStatus = .undefined
    var timestamp: Date?
    var startTimestamp: Date?
    var data: [String: Any] { [:] }
    var tags: [String: String] { [:] }
    var isFinished: Bool { false }
    var traceContext: TraceContext? { nil }

    // MARK: - Methods required by Span (no-ops)
    func startChild(operation: String) -> Span { return self }
    func startChild(operation: String, description: String?) -> Span { return self }
    func setData(value: Any?, key: String) {}
    func removeData(key: String) {}
    func setTag(value: String, key: String) {}
    func removeTag(key: String) {}
    func setMeasurement(name: String, value: NSNumber) {}
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit) {}
    func finish() {}
    func finish(status: SentrySpanStatus) {}
    func toTraceHeader() -> TraceHeader { return TraceHeader(trace: traceId, spanId: spanId, sampled: sampled) }
    func baggageHttpHeader() -> String? { return nil }

    // MARK: - SentrySerializable (no-op payload)
    func serialize() -> [String: Any] { return [:] }
}

private final class SubClassOfSentrySpan: SentrySpan {}
// swiftlint:enable file_length
