import XCTest

class SentryUserTests: XCTestCase {

    func testInitWithDictionary() {
        let dict: [AnyHashable: Any] = [
            "id": "fixture-id",
            "email": "fixture-email",
            "username": "fixture-username",
            "ip_address": "fixture-ip_address",
            "segment": "fixture-segment",
            "data": [
                "fixture-key": "fixture-value"
            ],
            "foo": "bar" // Unknown
        ]
        let user = PrivateSentrySDKOnly.user(with: dict)
        
        XCTAssertEqual(user.userId, "fixture-id")
        XCTAssertEqual(user.email, "fixture-email")
        XCTAssertEqual(user.username, "fixture-username")
        XCTAssertEqual(user.ipAddress, "fixture-ip_address")
        XCTAssertEqual(user.segment, "fixture-segment")
        XCTAssertEqual(user.data?["fixture-key"] as? String, "fixture-value")
        XCTAssertEqual(user.value(forKey: "unknown") as? NSDictionary, ["foo": "bar"])
    }
    
    func testSerializationWithAllProperties() {
        let user = TestData.user.copy() as! User
        user.setValue(["some": "data"], forKey: "unknown")
        
        let actual = user.serialize()

        // Changing the original doesn't modify the serialized
        user.userId = ""
        user.email = ""
        user.username = ""
        user.ipAddress = ""
        user.segment = ""
        user.name = ""
        user.geo = Geo()
        user.data?.removeAll()
        user.setValue(nil, forKey: "unknown")
        
        XCTAssertEqual(TestData.user.userId, actual["id"] as? String)
        XCTAssertEqual(TestData.user.email, actual["email"] as? String)
        XCTAssertEqual(TestData.user.username, actual["username"] as? String)
        XCTAssertEqual(TestData.user.ipAddress, actual["ip_address"] as? String)
        XCTAssertEqual(TestData.user.segment, actual["segment"] as? String)
        XCTAssertEqual(TestData.user.name, actual["name"] as? String)
        XCTAssertEqual(["some": ["data": "data", "date": TestData.timestampAs8601String]], actual["data"] as? Dictionary)
        XCTAssertEqual("data", actual["some"] as? String)
        
        let actualGeo = actual["geo"] as? [String: Any]
        XCTAssertEqual(TestData.user.geo?.city, actualGeo?["city"] as? String)
        XCTAssertEqual(TestData.user.geo?.countryCode, actualGeo?["country_code"] as? String)
        XCTAssertEqual(TestData.user.geo?.region, actualGeo?["region"] as? String)
    }
    
    func testSerializationWithOnlyId() {
        let user = User(userId: "someid")
        let actual = user.serialize()
        
        XCTAssertEqual(user.userId, actual["id"] as? String)
        XCTAssertEqual(1, actual.count)
    }
    
    func testSerializationWithoutId() {
        let user = User()
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
        XCTAssertEqual(TestData.user, TestData.user.copy() as! User)
    }
    
    func testNotIsEqual() {
        testIsNotEqual { user in user.userId = "" }
        testIsNotEqual { user in user.email = "" }
        testIsNotEqual { user in user.username = "" }
        testIsNotEqual { user in user.ipAddress = "" }
        testIsNotEqual { user in user.segment = "" }
        testIsNotEqual { user in user.name = "" }
        testIsNotEqual { user in user.geo = Geo() }
        testIsNotEqual { user in user.data?.removeAll() }
    }
    
    func testIsNotEqual(block: (User) -> Void ) {
        let user = TestData.user.copy() as! User
        block(user)
        XCTAssertNotEqual(TestData.user, user)
    }
    
    func testCopyWithZone_CopiesDeepCopy() {
        let user = TestData.user
        let copiedUser = user.copy() as! User
        
        // Modifying the original does not change the copy
        user.userId = ""
        user.email = ""
        user.username = ""
        user.ipAddress = ""
        user.segment = ""
        user.name = ""
        user.geo = Geo()
        user.data = [:]
        
        XCTAssertEqual(TestData.user, copiedUser)
    }
    
    func testModifyingFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentryUserTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        let user = TestData.user.copy() as! User
        
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
                    user.name = "\(i)"
                    
                    user.geo?.city = "\(i)"
                    user.geo?.countryCode = "\(i)"
                    user.geo?.region = "\(i)"
                    
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
