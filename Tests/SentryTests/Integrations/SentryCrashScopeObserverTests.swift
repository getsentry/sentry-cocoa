import XCTest

class SentryCrashScopeObserverTests: XCTestCase {
    
    private class Fixture {
        let dist = "dist"
        let environment = "environment"
        
        var sut: SentryCrashScopeObserver {
            return SentryCrashScopeObserver()
        }
    }
    
    private let fixture = Fixture()
    
    override func tearDown() {
        sentryscopesync_clear()
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
    
    func testClear() {
        let sut = fixture.sut
        let user = TestData.user
        sut.setUser(user)
        sut.setDist(fixture.dist)
        sut.setEnvironment(fixture.environment)
        
        sut.clear()
        
        let json = getScopeJSON()
        
        XCTAssertEqual("", json)
    }
    
    private func serialize(object: Any) -> String {
        let serialized = try! SentryCrashJSONCodec.encode(object, options: SentryCrashJSONEncodeOptionSorted)
        return String(data: serialized, encoding: .utf8) ?? ""
    }
    
    private func getScopeJSON() -> String {
        var jsonPointer = UnsafeMutablePointer<CChar>?(nil)
        let jsonLen = UnsafeMutablePointer<Int>.allocate(capacity: 0)
        sentryscopesync_getJSON(&jsonPointer, jsonLen)
        let json = String(cString: jsonPointer ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))
        
        jsonPointer?.deallocate()
        jsonLen.deallocate()
        
        return json
    }
}
