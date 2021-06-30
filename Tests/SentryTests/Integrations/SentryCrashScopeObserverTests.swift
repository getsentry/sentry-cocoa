import XCTest

class SentryCrashScopeObserverTests: XCTestCase {
    
    private class Fixture {
        let dist = "dist"
        let environment = "environment"
        let context = ["context": 1]
        
        var sut: SentryCrashScopeObserver {
            return SentryCrashScopeObserver()
        }
    }
    
    private let fixture = Fixture()
    
    override func tearDown() {
        sentryscopesync_clear()
        SentryCrash.sharedInstance().userInfo = nil
    }

    func testUser() {
        let sut = fixture.sut
        let user = TestData.user
        sut.setUser(user)
        
        let userJSON = serialize(object: user.serialize())
        let expected = "{\"user\":\(userJSON)}"
        
        let actual = getScopeJSON()
        XCTAssertEqual(expected, actual)
    }
    
    func testDist() {
        let sut = fixture.sut
        sut.setDist(fixture.dist)
        
        let distJSON = serialize(object: fixture.dist)
        let expected = "{\"dist\":\(distJSON)}"
        
        let actual = getScopeJSON()
        XCTAssertEqual(expected, actual)
    }
    
    func testEnvironment() {
        let sut = fixture.sut
        sut.setEnvironment(fixture.environment)
        
        let environmentJSON = serialize(object: fixture.environment)
        let expected = "{\"environment\":\(environmentJSON)}"
        
        let actual = getScopeJSON()
        XCTAssertEqual(expected, actual)
    }
    
    func testContext() {
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        
        setContext(scope)
        
        let contextJSON = serialize(object: fixture.context)
        let expected = "{\"context\":{\"context\":\(contextJSON)}}"
        
        let actual = getScopeJSON()
        XCTAssertEqual(expected, actual)
    }
    
    func testClear() {
        let sut = fixture.sut
        let user = TestData.user
        sut.setUser(user)
        sut.setDist(fixture.dist)
        sut.setEnvironment(fixture.environment)
        
        sut.clear()
        
        let json = getScopeJSON()
        
        XCTAssertEqual("{}", json)
    }
    
    func testEmptyScope() {
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        SentryCrash.sharedInstance().userInfo = scope.serialize()
        
        let expected = getUserInfoJSON()
        XCTAssertNotNil(expected)
        
        let actual = getScopeJSON()
        
        XCTAssertEqual(expected.sorted(), actual.sorted(), "\nJSON is not equal\nexpected:\n\(expected)\nactual:\n\(actual)")
    }
    
    func testUserInfoJSON() {
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        
        let tags = ["tag1": "tag1", "tag2": "tag2"]
        scope.setTags(tags)
        scope.setExtras(["extra1": "extra1", "extra2": "extra2"])
        scope.setFingerprint(["finger", "print"])
        setContext(scope)
        scope.setEnvironment("Production")
//        scope.setLevel(SentryLevel.fatal)
        
//        let crumb1 = TestData.crumb
//        crumb1.message = "Crumb 1"
//        scope.add(crumb1)
//
//        let crumb2 = TestData.crumb
//        crumb2.message = "Crumb 2"
//        scope.add(crumb2)
        
        scope.setUser(TestData.user)
        
        SentryCrash.sharedInstance().userInfo = scope.serialize()
        
        let expected = getUserInfoJSON()
        XCTAssertNotNil(expected)
        
        let actual = getScopeJSON()
        
        XCTAssertEqual(expected.sorted(), actual.sorted(), "\nJSON is not equal\nexpected:\n\(expected)\nactual:\n\(actual)")
    }
    
    private func setContext(_ scope: Scope) {
        scope.setContext(value: ["context": 1], key: "context")
    }
    
    private func getUserInfoJSON() -> String {
        var jsonPointer = UnsafeMutablePointer<CChar>?(nil)
        sentrycrashreport_getUserInfoJSON(&jsonPointer)
        let json = String(cString: jsonPointer ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))
        
        jsonPointer?.deallocate()
        
        return json
    }
    
    private func serialize(object: Any) -> String {
        let serialized = try! SentryCrashJSONCodec.encode(object, options: SentryCrashJSONEncodeOptionSorted)
        return String(data: serialized, encoding: .utf8) ?? ""
    }
    
    private func getScopeJSON() -> String {
        var jsonPointer = UnsafeMutablePointer<CChar>?(nil)
        sentryscopesync_getJSON(&jsonPointer)
        let json = String(cString: jsonPointer ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))
        jsonPointer?.deallocate()
        return json
    }
}
