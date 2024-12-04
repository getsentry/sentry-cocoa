import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"

    override func setUp() {
        SentryMeta.sdkName = sdkName
    }

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
            XCTAssertEqual(3, sdkInfo.count)
            XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
            XCTAssertEqual(version, sdkInfo["version"] as? String)
            XCTAssertEqual(0, (sdkInfo["packages"] as? [[String: Any]])?.count)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testSPM_packageInfo() throws {
        let version = useVersion("5.2.0")
        let actual = SentrySdkInfo(name: sdkName, andVersion: version, andPackages: [SentrySdkPackage.getSentrySDKPackage(0)!])
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: Any]])
            XCTAssertEqual(1, packages.count)

            XCTAssertEqual(packages[0]["name"] as? String, "spm:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"] as? String, version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testCarthage_packageInfo() throws {
        let version = useVersion("5.2.0")
        let actual = SentrySdkInfo(name: sdkName, andVersion: version, andPackages: [SentrySdkPackage.getSentrySDKPackage(2)!])
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: Any]])
            XCTAssertEqual(1, packages.count)

            XCTAssertEqual(packages[0]["name"] as? String, "carthage:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"] as? String, version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testcocoapods_packageInfo() throws {
        let version = useVersion("5.2.0")
        let actual = SentrySdkInfo(name: sdkName, andVersion: version, andPackages: [SentrySdkPackage.getSentrySDKPackage(1)!])
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: Any]])
            XCTAssertEqual(1, packages.count)

            XCTAssertEqual(packages[0]["name"] as? String, "cocoapods:getsentry/\(sdkName)")
            XCTAssertEqual(packages[0]["version"] as? String, version)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func test_multiple_packages() throws {
        let version = useVersion("5.2.0")
        let actual = SentrySdkInfo(name: sdkName, andVersion: version, andPackages: [
            SentrySdkPackage(name: "package1", andVersion: "version1"),
            SentrySdkPackage(name: "package2", andVersion: "version2")
        ])
        let serialization = actual.serialize()

        if let sdkInfo = serialization["sdk"] as? [String: Any] {
            XCTAssertEqual(3, sdkInfo.count)

            let packages = try XCTUnwrap(sdkInfo["packages"] as? [[String: Any]])
            XCTAssertEqual(2, packages.count)

            XCTAssertEqual(packages[0]["name"] as? String, "package1")
            XCTAssertEqual(packages[0]["version"] as? String, "version1")
            XCTAssertEqual(packages[1]["name"] as? String, "package2")
            XCTAssertEqual(packages[1]["version"] as? String, "version2")
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk")
        }
    }

    func testPackageManagerOption () {
        XCTAssertNil(SentrySdkPackage.getSentrySDKPackage(3))
    }

    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, andVersion: version)
        
        let dict = ["sdk": [ "name": sdkName, "version": version]]
        
        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_LegacyPackageInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, andVersion: version)

        let dict: [String : Any] = ["sdk": [ "name": sdkName, "version": version, "packages": ["name": "package1", "version": "version1"]]]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_IncludePackages() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, andVersion: version, andPackages: [
            SentrySdkPackage(name: "package1", andVersion: "version1"),
            SentrySdkPackage(name: "package2", andVersion: "version2")
        ])

        let dict: [String : Any] = ["sdk": [ "name": sdkName, "version": version, "packages": [
            ["name": "package1", "version": "version1"],
            ["name": "package2", "version": "version2"]
        ]]]

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
        XCTAssertEqual(SentrySdkInfo(name: "", andVersion: ""), actual)
    }

    private func useVersion(_ version: String) -> String {
        SentryMeta.versionString = version
        return version
    }
}
