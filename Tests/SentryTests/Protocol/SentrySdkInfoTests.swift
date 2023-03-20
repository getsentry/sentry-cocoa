import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"
    
    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let actual = SentrySdkInfo(name: sdkName, andVersion: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let actual = SentrySdkInfo(name: sdkName, andVersion: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, andVersion: version).serialize()
        
        if let sdkInfo = actual["sdk"] as? [String: Any] {
            XCTAssertEqual(2, sdkInfo.count)
            XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
            XCTAssertEqual(version, sdkInfo["version"] as? String)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testSPM_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, andVersion: version)
        Dynamic(actual).packageManager = 0
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packageInfo = try XCTUnwrap(sdkInfo["packages"] as? [String: Any])
            XCTAssertEqual(packageInfo["name"] as? String, "spm:getsentry/\(sdkName)")
            XCTAssertEqual(packageInfo["version"] as? String, version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testPackageNames () {
        let actual = SentrySdkInfo(name: sdkName, andVersion: "")
        XCTAssertEqual(Dynamic(actual).getPackageName(0), "spm:getsentry/%@")
        XCTAssertEqual(Dynamic(actual).getPackageName(1), "cocoapods:getsentry/%@")
        XCTAssertEqual(Dynamic(actual).getPackageName(2), "carthage:getsentry/%@")
        XCTAssertNil(Dynamic(actual).getPackageName(3).asString)
    }
    
    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, andVersion: version)
        
        let dict = ["sdk": [ "name": sdkName, "version": version]]
        
        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_AllNil() {
        let dict = ["sdk": [ "name": nil, "version": nil]]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = ["sdk": [ "name": 0, "version": 0]]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_SdkInfoIsString() {
        let dict = ["sdk": ""]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    private func assertEmptySdkInfo(actual: SentrySdkInfo) {
        XCTAssertEqual(SentrySdkInfo(name: "", andVersion: ""), actual)
    }
}
