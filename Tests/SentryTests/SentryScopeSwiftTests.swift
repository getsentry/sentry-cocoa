import XCTest

class SentryScopeSwiftTests: XCTestCase {

    private class Fixture {
        let user: User
        let breadcrumb: Breadcrumb
        let scope: Scope
        let date: Date
        
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
            breadcrumb.message = "Click something"
            breadcrumb.data = ["some": ["data": "data", "date": date]]
            
            scope = Scope(maxBreadcrumbs: 5)
            scope.setUser(user)
            scope.setTag(value: "value", key: "key")
            scope.setExtra(value: "value", key: "key")
            scope.setDist("dist")
            scope.setEnvironment("environment")
            scope.setFingerprint(["fingerprint"])
            scope.setContext(value: ["c": "a"], key: "context")
            scope.setLevel(SentryLevel.info)
            scope.add(breadcrumb)
        }
        
        var dateAs8601String: String {
            get {
                return (date as NSDate).sentry_toIso8601String()
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

        XCTAssertNotEqual(Scope(maxBreadcrumbs: 5), Scope(maxBreadcrumbs: 4))
    }
    
    func testIsNotEqual(block: (Scope) -> Void ) {
        let scope = Fixture().scope
        block(scope)
        XCTAssertNotEqual(fixture.scope, scope)
    }

}
