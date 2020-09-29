import XCTest

class SentryUserTests: XCTestCase {
    
    private class Fixture {
        
        let date: Date
        let user: User
        
        init() {
            date = Date(timeIntervalSince1970: 10)
            
            user = User(userId: "id")
            user.email = "user@sentry.io"
            user.username = "user123"
            user.ipAddress = "127.0.0.1"
            user.data = ["some": ["data": "data", "date": date]]
        }
        
        var dateAs8601String: String {
            get {
                return (date as NSDate).sentry_toIso8601String()
            }
        }
    }
    
    private let fixture = Fixture()
    
    func testSerializationWithAllProperties() {
        let actual = fixture.user.serialize()
        
        XCTAssertEqual(fixture.user.userId, actual["id"] as? String)
        XCTAssertEqual(fixture.user.email, actual["email"] as? String)
        XCTAssertEqual(fixture.user.username, actual["username"] as? String)
        XCTAssertEqual(fixture.user.ipAddress, actual["ip_address"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": fixture.dateAs8601String]], actual["data"] as? Dictionary)
    }
    
    func testSerializationWithOnlyId() {
        let user = User(userId: "someid")
        let actual = user.serialize()
        
        XCTAssertEqual(user.userId, actual["id"] as? String)
        XCTAssertEqual(1, actual.count)
    }
    
    func testHash() {
        let fixture2 = Fixture()
        XCTAssertEqual(fixture.user.hash(), fixture2.user.hash())
        
        let user2 = fixture2.user
        user2.email = "some"
        XCTAssertNotEqual(fixture.user.hash(), user2.hash())
    }
    
    func testIsEqualToSelf() {
        XCTAssertEqual(fixture.user, fixture.user)
        XCTAssertTrue(fixture.user.isEqual(to: fixture.user))
    }
    
    func testIsNotEqualToOtherClass() {
        XCTAssertFalse(fixture.user.isEqual(1))
    }
    
    func testIsEqualToCopy() {
        XCTAssertEqual(fixture.user, fixture.user.copy() as! User)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { user in user.userId = "" }
        testIsNotEqual { user in user.email = "" }
        testIsNotEqual { user in user.username = "" }
        testIsNotEqual { user in user.ipAddress = "" }
        testIsNotEqual { user in user.data?.removeAll() }
    }
    
    func testIsNotEqual(block: (User) -> Void ) {
        let user = fixture.user.copy() as! User
        block(user)
        XCTAssertNotEqual(fixture.user, user)
    }
}
