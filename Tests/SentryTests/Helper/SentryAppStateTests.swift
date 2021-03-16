import XCTest

class SentryAppStateTests: XCTestCase {

    func testSerialize() {
        let appState = TestData.appState
        
        let actual = appState.serialize()
        
        XCTAssertEqual(appState.appVersion, actual["app_version"] as? String)
        XCTAssertEqual(appState.osVersion, actual["os_version"] as? String)
        XCTAssertEqual(appState.isDebugging, actual["is_debugging"] as? Bool)
        XCTAssertEqual(appState.isActive, actual["is_active"] as? Bool)
        XCTAssertEqual(appState.wasTerminated, actual["was_terminated"] as? Bool)
    }
    
    func testInitWithJSON_AllFields() {
        let appState = TestData.appState
        let dict = [
            "app_version": appState.appVersion,
            "os_version": appState.osVersion,
            "is_debugging": appState.isDebugging,
            "is_active": appState.isActive,
            "was_terminated": appState.wasTerminated
        ] as [String: Any]
        
        let actual = SentryAppState(jsonObject: dict)
        
        XCTAssertEqual(appState, actual)
    }
    
    func testInitWithJSON_IfJsonMissesField_AppStateIsNil() {
        withValue { $0["app_version"] = nil }
        withValue { $0["os_version"] = nil }
        withValue { $0["is_debugging"] = nil }
        withValue { $0["is_active"] = nil }
        withValue { $0["was_terminated"] = nil }
    }
    
    func testInitWithJSON_IfJsonContainsWrongField_AppStateIsNil() {
        withValue { $0["app_version"] = 0 }
        withValue { $0["os_version"] = nil }
        withValue { $0["is_debugging"] = "" }
        withValue { $0["is_active"] = "" }
        withValue { $0["was_terminated"] = "" }
    }
    
    func withValue(setValue: (inout [String: Any]) -> Void) {
        let expected = TestData.appState
        var serialized = expected.serialize()
        setValue(&serialized)
        XCTAssertNil(SentryAppState(jsonObject: serialized))
    }

}
