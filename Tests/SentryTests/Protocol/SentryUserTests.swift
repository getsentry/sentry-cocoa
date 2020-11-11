import XCTest

class SentryUserTests: XCTestCase {
    
    func testSerializationWithAllProperties() {
        let actual = TestData.user.serialize()
        
        XCTAssertEqual(TestData.user.userId, actual["id"] as? String)
        XCTAssertEqual(TestData.user.email, actual["email"] as? String)
        XCTAssertEqual(TestData.user.username, actual["username"] as? String)
        XCTAssertEqual(TestData.user.ipAddress, actual["ip_address"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": TestData.timestampAs8601String]], actual["data"] as? Dictionary)
    }
    
    func testSerializationWithOnlyId() {
        let user = User(userId: "someid")
        let actual = user.serialize()
        
        XCTAssertEqual(user.userId, actual["id"] as? String)
        XCTAssertEqual(1, actual.count)
    }
    
    func testHash() {
        XCTAssertEqual(TestData.user.hash(), TestData.user.hash())
        
        let user2 = TestData.user
        user2.email = "some"
        XCTAssertNotEqual(TestData.user.hash(), user2.hash())
    }
    
    func testIsEqualToSelf() {
        XCTAssertEqual(TestData.user, TestData.user)
        XCTAssertTrue(TestData.user.isEqual(to: TestData.user))
    }
    
    func testIsNotEqualToOtherClass() {
        XCTAssertFalse(TestData.user.isEqual(1))
    }
    
    func testIsEqualToCopy() {
        XCTAssertEqual(TestData.user, TestData.user.copy() as! User)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { user in user.userId = "" }
        testIsNotEqual { user in user.email = "" }
        testIsNotEqual { user in user.username = "" }
        testIsNotEqual { user in user.ipAddress = "" }
        testIsNotEqual { user in user.data?.removeAll() }
    }
    
    func testIsNotEqual(block: (User) -> Void ) {
        let user = TestData.user.copy() as! User
        block(user)
        XCTAssertNotEqual(TestData.user, user)
    }
}
