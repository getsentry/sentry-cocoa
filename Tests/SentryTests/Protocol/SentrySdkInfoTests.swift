@testable import Sentry
import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"
    
    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let actual = SentrySdkInfo(name: sdkName, version: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let actual = SentrySdkInfo(name: sdkName, version: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version).serialize()
        
        if let sdkInfo = actual["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)
            XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
            XCTAssertEqual(version, sdkInfo["version"] as? String)
            XCTAssertEqual([], sdkInfo["packages"] as? [[String: String]])
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testSPM_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, packageManager: .spm)
        Dynamic(actual).packageManager = SentrySdkPackageManager.spm
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: String]])
            XCTAssertEqual(packages.count, 1)
            XCTAssertEqual(packages[0]["name"], "spm:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"], version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testCarthage_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, packageManager: .carthage)
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: String]])
            XCTAssertEqual(packages.count, 1)
            XCTAssertEqual(packages[0]["name"], "carthage:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"], version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testcocoapods_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, packageManager: .cocoapods)
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: String]])
            XCTAssertEqual(packages.count, 1)
            XCTAssertEqual(packages[0]["name"], "cocoapods:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"], version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testNoPackageNames () {
        XCTAssertNil(SentrySdkInfo.getPackageName(.unknown, ""))
    }
    
    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, version: version)
        
        let dict = ["sdk": [ "name": sdkName, "version": version]]
        
        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_AllNil() {
        let dict = ["sdk": [ "name": nil, "version": nil] as [String: Any?]]
        
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
        XCTAssertEqual(SentrySdkInfo(name: "", version: ""), actual)
    }
}
