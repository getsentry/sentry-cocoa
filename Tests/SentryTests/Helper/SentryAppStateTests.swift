import XCTest

class SentryAppStateTests: XCTestCase {

    func testSerialize() {
        let appState = TestData.appState
        
        let actual = appState.serialize()
        
        XCTAssertEqual(appState.releaseName, actual["release_name"] as? String)
        XCTAssertEqual(appState.osVersion, actual["os_version"] as? String)
        XCTAssertEqual(appState.isDebugging, actual["is_debugging"] as? Bool)
        XCTAssertEqual((appState.systemBootTimestamp as NSDate).sentry_toIso8601String(), actual["system_boot_timestamp"] as? String)
        XCTAssertEqual(appState.isActive, actual["is_active"] as? Bool)
        XCTAssertEqual(appState.wasTerminated, actual["was_terminated"] as? Bool)
        XCTAssertEqual(appState.isANROngoing, actual["is_anr_ongoing"] as? Bool)
        XCTAssertEqual(appState.isSDKRunning, actual["is_sdk_running"] as? Bool)
    }
    
    func testInitWithJSON_AllFields() {
        let appState = TestData.appState
        let dict = [
            "release_name": appState.releaseName,
            "os_version": appState.osVersion,
            "vendor_id": appState.vendorId,
            "is_debugging": appState.isDebugging,
            "system_boot_timestamp": (appState.systemBootTimestamp as NSDate).sentry_toIso8601String(),
            "is_active": appState.isActive,
            "was_terminated": appState.wasTerminated,
            "is_anr_ongoing": appState.isANROngoing,
            "is_sdk_running": appState.isSDKRunning
        ] as [String: Any]
        
        let actual = SentryAppState(jsonObject: dict)
        
        XCTAssertEqual(appState, actual)
    }
    
    func testInitWithJSON_IfJsonMissesField_AppStateIsNil() {
        withValue { $0["release_name"] = nil }
        withValue { $0["os_version"] = nil }
        withValue { $0["vendor_id"] = nil }
        withValue { $0["is_debugging"] = nil }
        withValue { $0["system_boot_timestamp"] = nil }
        withValue { $0["is_active"] = nil }
        withValue { $0["was_terminated"] = nil }
        withValue { $0["is_anr_ongoing"] = nil }
    }

    func testInitWithJSON_IfJsonContainsWrongField_AppStateIsNil() {
        withValue { $0["release_name"] = 0 }
        withValue { $0["os_version"] = nil }
        withValue { $0["vendor_id"] = nil }
        withValue { $0["is_debugging"] = "" }
        withValue { $0["system_boot_timestamp"] = "" }
        withValue { $0["is_active"] = "" }
        withValue { $0["was_terminated"] = "" }
        withValue { $0["is_anr_ongoing"] = "" }
    }
    
    func testBootTimeRoundedDownToSeconds() {
        
        let date = Date(timeIntervalSince1970: 0.1)
        let expectedDate = Date(timeIntervalSince1970: 0)
        
        let sut = SentryAppState(releaseName: "", osVersion: "", vendorId: "", isDebugging: false, systemBootTimestamp: date)
        
        XCTAssertEqual(expectedDate, sut.systemBootTimestamp)
    }
    
    func withValue(setValue: (inout [String: Any]) -> Void) {
        let expected = TestData.appState
        var serialized = expected.serialize()
        setValue(&serialized)
        XCTAssertNil(SentryAppState(jsonObject: serialized))
    }
}
