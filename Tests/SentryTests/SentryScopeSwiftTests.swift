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
        let maxBreadcrumbs = 5

        init() {
            date = Date(timeIntervalSince1970: 10)
            
            user = User(userId: "id")
            user.email = "user@sentry.io"
            user.username = "user123"
            user.ipAddress = ipAddress
            user.data = ["some": ["data": "data", "date": date]]
            
            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = date
            breadcrumb.type = "user"
            breadcrumb.message = "Clicked something"
            breadcrumb.data = ["some": ["data": "data", "date": date]]
            
            scope = Scope(maxBreadcrumbs: maxBreadcrumbs)
            scope.setUser(user)
            scope.setTag(value: tags["key"] ?? "", key: "key")
            scope.setExtra(value: extra["key"] ?? "", key: "key")
            scope.setDist(dist)

            scope.setEnvironment(environment)
            scope.setFingerprint(fingerprint)

            scope.setContext(value: context["context"] ?? ["": ""], key: "context")
            scope.setLevel(level)
            scope.add(breadcrumb)
            
            scope.add(TestData.fileAttachment)
            
            event = Event()
            event.message = SentryMessage(formatted: "message")
            
            transaction = SentryTracer(transactionContext: TransactionContext(name: transactionName, operation: "op"), hub: nil)
        }
        
        var dateAs8601String: String {
            get {
                (date as NSDate).sentry_toIso8601String()
            }
        }
    }
    
    private let fixture = Fixture()
    
    func testSerialize() {
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
        scope.add(TestData.fileAttachment)
        scope.span = fixture.transaction
        
        XCTAssertEqual(["key": "value"], actual["tags"] as? [String: String])
        XCTAssertEqual(["key": "value"], actual["extra"] as? [String: String])
        XCTAssertEqual(fixture.context, actual["context"] as? [String: [String: String]])
        
        let actualUser = actual["user"] as? [String: Any]
        XCTAssertEqual(fixture.ipAddress, actualUser?["ip_address"] as? String)
        
        XCTAssertEqual("dist", actual["dist"] as? String)
        XCTAssertEqual(fixture.environment, actual["environment"] as? String)
        XCTAssertEqual(fixture.fingerprint, actual["fingerprint"] as? [String])
        XCTAssertEqual("info", actual["level"] as? String)
        XCTAssertNil(actual["transaction"])
        XCTAssertNotNil(actual["breadcrumbs"])
    }
    
    func testApplyToEvent() {
        let actual = fixture.scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(fixture.tags, actual?.tags)
        XCTAssertEqual(fixture.extra, actual?.extra as? [String: String])
        XCTAssertEqual(fixture.user, actual?.user)
        XCTAssertEqual(fixture.dist, actual?.dist)
        XCTAssertEqual(fixture.environment, actual?.environment)
        XCTAssertEqual(fixture.fingerprint, actual?.fingerprint)
        XCTAssertEqual(fixture.level, actual?.level)
        XCTAssertEqual([fixture.breadcrumb], actual?.breadcrumbs)
        XCTAssertEqual(fixture.context, actual?.context as? [String: [String: String]])
    }
    
    func testApplyToEvent_EventWithTags() {
        let tags = NSMutableDictionary(dictionary: ["my": "tag"])
        let event = fixture.event
        event.tags = tags as? [String: String]
        
        let actual = fixture.scope.apply(to: event, maxBreadcrumb: 10)
        
        tags.addEntries(from: fixture.tags)
        XCTAssertEqual(tags as? [String: String], actual?.tags)
    }
    
    func testApplyToEvent_EventWithExtra() {
        let extra = NSMutableDictionary(dictionary: ["my": "extra"])
        let event = fixture.event
        event.extra = extra as? [String: String]
        
        let actual = fixture.scope.apply(to: event, maxBreadcrumb: 10)
        
        extra.addEntries(from: fixture.extra)
        XCTAssertEqual(extra as? [String: String], actual?.extra as? [String: String])
    }
    
    func testApplyToEvent_ScopeWithoutUser() {
        let scope = fixture.scope
        scope.setUser(nil)
        
        let event = fixture.event
        event.user = fixture.user
        
        let actual = scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(fixture.user, actual?.user)
    }
    
    func testApplyToEvent_ScopeWithoutDist() {
        let scope = fixture.scope
        scope.setDist(nil)
        
        let event = fixture.event
        event.dist = "myDist"
        
        let actual = scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(event.dist, actual?.dist)
    }
    
    func testApplyToEvent_EventWithDist() {
        let event = fixture.event
        event.dist = "myDist"
        
        let actual = fixture.scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(event.dist, actual?.dist)
    }
    
    func testApplyToEvent_ScopeWithoutEnvironment() {
        let scope = fixture.scope
        scope.setEnvironment(nil)
        
        let event = fixture.event
        event.environment = "myEnvironment"
        
        let actual = scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(event.environment, actual?.environment)
    }
    
    func testApplyToEvent_EventWithEnvironment() {
        let event = fixture.event
        event.environment = "myEnvironment"
        
        let actual = fixture.scope.apply(to: fixture.event, maxBreadcrumb: 10)
        
        XCTAssertEqual(event.environment, actual?.environment)
    }
    
    func testUseSpan() {
        fixture.scope.span = fixture.transaction
        fixture.scope.useSpan { (span) in
            XCTAssert(span === self.fixture.transaction)
        }
    }
    
    func testUseSpanForClear() {
        fixture.scope.span = fixture.transaction
        fixture.scope.useSpan { (span) in
            self.fixture.scope.span = nil
        }
        XCTAssertNil(fixture.scope.span)
    }
    
    func testApplyToEvent_EventWithContext() {
        let context = NSMutableDictionary(dictionary: ["my": ["extra": "context"]])
        let event = fixture.event
        event.context = context as? [String: [String: String]]
        
        let actual = fixture.scope.apply(to: event, maxBreadcrumb: 10)
        
        context.addEntries(from: fixture.context)
        XCTAssertEqual(context as? [String: [String: String]],
                       actual?.context as? [String: [String: String]])
    }
        
    func testClear() {
        let scope = fixture.scope
        scope.clear()
        
        let expected = Scope(maxBreadcrumbs: fixture.maxBreadcrumbs)
        XCTAssertEqual(expected, scope)
        XCTAssertEqual(0, scope.attachments.count)
    }
    
    func testAttachmentsIsACopy() {
        let scope = fixture.scope
        
        let attachments = scope.attachments
        scope.add(TestData.fileAttachment)
        
        XCTAssertEqual(1, attachments.count)
    }
    
    // Altough we only run this test above the below specified versions, we exped the
    // implementation to be thread safe
    // With this test we test if modifications from multiple threads don't lead to a crash.
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testModifyingFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentryScopeTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        let scope = fixture.scope
        
        for _ in 0...20 {
            group.enter()
            queue.async {
                
                // The number is kept small for the CI to not take to long.
                // If you really want to test this increase to 100_000 or so.
                for _ in 0...1_000 {
                    
                    // Simulate some real world modifications of the user
                    
                    let key = "key"
                    
                    _ = Scope(scope: scope)
                    
                    for _ in 0...100 {
                        scope.add(self.fixture.breadcrumb)
                    }
                    
                    scope.serialize()
                    scope.clearBreadcrumbs()
                    scope.add(self.fixture.breadcrumb)
                    
                    scope.apply(to: SentrySession(releaseName: "1.0.0"))
                    
                    scope.setFingerprint(nil)
                    scope.setFingerprint(["finger", "print"])
                    
                    scope.setContext(value: ["some": "value"], key: key)
                    scope.removeContext(key: key)
                    
                    scope.setExtra(value: 1, key: key)
                    scope.removeExtra(key: key)
                    scope.setExtras(["value": "1", "value2": "2"])
                    
                    scope.apply(to: TestData.event, maxBreadcrumb: 5)
                    
                    scope.setTag(value: "value", key: key)
                    scope.removeTag(key: key)
                    scope.setTags(["tag1": "hello", "tag2": "hello"])
                    
                    scope.add(TestData.fileAttachment)
                    
                    for _ in 0...10 {
                        scope.add(self.fixture.breadcrumb)
                    }
                    scope.serialize()
                    
                    scope.setUser(self.fixture.user)
                    scope.setDist("dist")
                    scope.setEnvironment("env")
                    scope.setLevel(SentryLevel.debug)
                    
                    scope.apply(to: SentrySession(releaseName: "1.0.0"))
                    scope.apply(to: TestData.event, maxBreadcrumb: 5)
                    
                    scope.serialize()
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.waitWithTimeout(timeout: 500)
    }
}
