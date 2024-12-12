import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"
    
    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let actual = SentrySdkInfo(name: sdkName, version: version, integrations: [], features: [])

        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let actual = SentrySdkInfo(name: sdkName, version: version, integrations: [], features: [])
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let sdkInfo = SentrySdkInfo(name: sdkName, version: version, integrations: ["a"], features: ["b"]).serialize()

        XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
        XCTAssertEqual(version, sdkInfo["version"] as? String)
        XCTAssertEqual(["a"], sdkInfo["integrations"] as? [String])
        XCTAssertEqual(["b"], sdkInfo["features"] as? [String])
    }

    func testSerializationValidIntegrations() {
        let sdkInfo = SentrySdkInfo(name: "", version: "", integrations: ["a", "b"], features: []).serialize()

        XCTAssertEqual(["a", "b"], sdkInfo["integrations"] as? [String])
    }

    func testSerializationValidFeatures() {
        let sdkInfo = SentrySdkInfo(name: "", version: "", integrations: [], features: ["c", "d"]).serialize()

        XCTAssertEqual(["c", "d"], sdkInfo["features"] as? [String])
    }

    func testSPM_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, integrations: [], features: [])
        Dynamic(actual).packageManager = 0
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "spm:getsentry/\(sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, version)
    }

    func testCarthage_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, integrations: [], features: [])
        Dynamic(actual).packageManager = 2
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "carthage:getsentry/\(sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, version)
    }

    func testcocoapods_packageInfo() throws {
        let version = "5.2.0"
        let actual = SentrySdkInfo(name: sdkName, version: version, integrations: [], features: [])
        Dynamic(actual).packageManager = 1
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "cocoapods:getsentry/\(sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, version)
    }

    func testNoPackageNames () {
        let actual = SentrySdkInfo(name: sdkName, version: "", integrations: [], features: [])
        XCTAssertNil(Dynamic(actual).getPackageName(3).asString)
    }
    
    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(name: sdkName, version: version, integrations: ["a", "b"], features: ["c", "d"])

        let dict = [ "name": sdkName, "version": version, "integrations": ["a", "b"], "features": ["c", "d"]] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_AllNil() {
        let dict = [ "name": nil, "version": nil, "integraions": nil, "features": nil] as [String: Any?]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict as [AnyHashable: Any]))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = [ "name": 0, "version": 0, "integrations": 0, "features": 0]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_SdkInfoIsString() {
        let dict = ["sdk": ""]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }

    func testFromGlobals() throws {
        SentrySDK.start(options: Options())
        let actual = SentrySdkInfo.fromGlobals()
        XCTAssertEqual(actual.name, SentryMeta.sdkName)
        XCTAssertEqual(actual.version, SentryMeta.versionString)
        XCTAssertTrue(actual.integrations.count > 0)
        XCTAssertTrue(actual.features.count > 0)
    }

    private func assertEmptySdkInfo(actual: SentrySdkInfo) {
        XCTAssertEqual(SentrySdkInfo(name: "", version: "", integrations: [], features: []), actual)
    }
}
