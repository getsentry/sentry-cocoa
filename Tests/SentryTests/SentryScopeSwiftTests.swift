import XCTest

class SentryScopeSwiftTests: XCTestCase {

    private class Fixture {
        let user: User
        let breadcrumb: Breadcrumb
        let scope: Scope
        let date: Date
        let event: Event

        let dist = "dist"
        let environment = "environment"
        let fingerprint = ["fingerprint"]
        let context = ["context": ["c": "a"]]
        let tags = ["key": "value"]
        let extra = ["key": "value"]
        let level = SentryLevel.info
        
        let maxBreadcrumbs = 5

        init() {
            date = Date(timeIntervalSince1970: 10)
            
            user = User(userId: "id")
            user.email = "user@sentry.io"
            user.username = "user123"
            user.ipAddress = "127.0.0.1"
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
            
            event = Event()
            event.message = SentryMessage(formatted: "message")
        }
        
        var dateAs8601String: String {
            get {
                (date as NSDate).sentry_toIso8601String()
            }
        }
    }
    
    private let fixture = Fixture()

    func testHash() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.scope.hash(), fixture2.scope.hash())
        
        let scope2 = fixture2.scope
        scope2.setEnvironment("other environment")
        XCTAssertNotEqual(fixture.scope.hash(), scope2.hash())
    }
    
    func testIsEqualToSelf() {
        XCTAssertEqual(fixture.scope, fixture.scope)
        XCTAssertTrue(fixture.scope.isEqual(to: fixture.scope))
    }
    
    func testIsNotEqualToOtherClass() {
        XCTAssertFalse(fixture.scope.isEqual(1))
    }

    func testIsEqualToOtherInstanceWithSameValues() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.scope, fixture2.scope)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { scope in scope.setUser(User()) }
        testIsNotEqual { scope in scope.setTag(value: "h", key: "a") }
        testIsNotEqual { scope in scope.setExtra(value: "h", key: "a") }
        testIsNotEqual { scope in scope.setContext(value: ["some": "context"], key: "hello") }
        testIsNotEqual { scope in scope.setDist("") }
        testIsNotEqual { scope in scope.setEnvironment("") }
        testIsNotEqual { scope in scope.setFingerprint([]) }
        testIsNotEqual { scope in scope.add(Breadcrumb()) }
        testIsNotEqual { scope in scope.clear() }
        testIsNotEqual { scope in scope.setLevel(SentryLevel.error) }

        XCTAssertNotEqual(Scope(maxBreadcrumbs: fixture.maxBreadcrumbs), Scope(maxBreadcrumbs: 4))
    }
    
    private func testIsNotEqual(block: (Scope) -> Void ) {
        let scope = Fixture().scope
        block(scope)
        XCTAssertNotEqual(fixture.scope, scope)
    }
    
    func testSerialize() {
        let actual = fixture.scope.serialize()
        
        XCTAssertEqual(["key": "value"], actual["tags"] as? [String: String])
        XCTAssertEqual(["key": "value"], actual["extra"] as? [String: String])
        XCTAssertEqual(fixture.context, actual["context"] as? [String: [String: String]])
        
        let actualUser = actual["user"] as? [String: Any]
        XCTAssertEqual(fixture.user.ipAddress, actualUser?["ip_address"] as? String )
        
        XCTAssertEqual("dist", actual["dist"] as? String)
        XCTAssertEqual(fixture.environment, actual["environment"] as? String)
        XCTAssertEqual(fixture.fingerprint, actual["fingerprint"] as? [String])
        XCTAssertEqual("info", actual["level"] as? String)
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
    }
}
