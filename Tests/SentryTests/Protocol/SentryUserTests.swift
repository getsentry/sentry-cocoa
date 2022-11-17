import XCTest

class SentryUserTests: XCTestCase {

    func testSerializationWithAllProperties() {
        let user = TestData.user.copy() as! SentryUser
        let actual = user.serialize()

        // Changing the original doesn't modify the serialized
        user.userId = ""
        user.email = ""
        user.username = ""
        user.ipAddress = ""
        user.segment = ""
        user.data?.removeAll()
        
        XCTAssertEqual(TestData.user.userId, actual["id"] as? String)
        XCTAssertEqual(TestData.user.email, actual["email"] as? String)
        XCTAssertEqual(TestData.user.username, actual["username"] as? String)
        XCTAssertEqual(TestData.user.ipAddress, actual["ip_address"] as? String)
        XCTAssertEqual(TestData.user.segment, actual["segment"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": TestData.timestampAs8601String]], actual["data"] as? Dictionary)
    }
    
    func testSerializationWithOnlyId() {
        let user = SentryUser(userId: "someid")
        let actual = user.serialize()
        
        XCTAssertEqual(user.userId, actual["id"] as? String)
        XCTAssertEqual(1, actual.count)
    }

    func testSerializationWithoutId() {
        let user = SentryUser()
        let actual = user.serialize()

        XCTAssertNil(actual["id"] as? String)
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
        XCTAssertEqual(TestData.user, TestData.user.copy() as! SentryUser)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { user in user.userId = "" }
        testIsNotEqual { user in user.email = "" }
        testIsNotEqual { user in user.username = "" }
        testIsNotEqual { user in user.ipAddress = "" }
        testIsNotEqual { user in user.segment = "" }
        testIsNotEqual { user in user.data?.removeAll() }
    }
    
    func testIsNotEqual(block: (SentryUser) -> Void ) {
        let user = TestData.user.copy() as! SentryUser
        block(user)
        XCTAssertNotEqual(TestData.user, user)
    }
    
    func testCopyWithZone_CopiesDeepCopy() {
        let user = TestData.user
        let copiedUser = user.copy() as! SentryUser
        
        // Modifying the original does not change the copy
        user.userId = ""
        user.email = ""
        user.username = ""
        user.ipAddress = ""
        user.segment = ""
        user.data = [:]
        
        XCTAssertEqual(TestData.user, copiedUser)
    }
    
    // Although we only run this test above the below specified versions, we expect the
    // implementation to be thread safe
    // With this test we test if modifications from multiple threads don't lead to a crash.
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testModifyingFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentryScopeTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        let user = TestData.user.copy() as! SentryUser
        
        for i in 0...20 {
            group.enter()
            queue.async {
                
                // The number is kept small for the CI to not take to long.
                // If you really want to test this increase to 100_000 or so.
                for _ in 0...1_000 {
                    
                    // Simulate some real world modifications of the user
                    
                    user.userId = "\(i)"
                    
                    // Trigger is equal
                    user.isEqual(to: TestData.user)
                    user.serialize()
                    
                    user.serialize()
                    
                    user.email = "john@example.com"
                    user.username = "\(i)"
                    user.ipAddress = "\(i)"
                    user.segment = "\(i)"
                    
                    user.data?["\(i)"] = "\(i)"
                    
                    // Trigger hash
                    XCTAssertNotNil([user: user])
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.waitWithTimeout()
    }
}
