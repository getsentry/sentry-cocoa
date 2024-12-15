import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"

    func cleanUp() {
        SentrySdkInfo.resetPackageManager()
        SentrySdkInfo.clearExtraPackages()
    }

    override func setUp() {
        cleanUp()
    }

    override func tearDown() {
        cleanUp()
    }

    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let actual = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: [],
            features: [],
            packages: []
        )

        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let actual = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: [],
            features: [],
            packages: []
        )
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let sdkInfo = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a"],
            features: ["b"],
            packages: []
        ).serialize()

        XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
        XCTAssertEqual(version, sdkInfo["version"] as? String)
        XCTAssertEqual(["a"], sdkInfo["integrations"] as? [String])
        XCTAssertEqual(["b"], sdkInfo["features"] as? [String])
    }

    func testSerializationValidIntegrations() {
        let sdkInfo = SentrySdkInfo(
            name: "",
            version: "",
            integrations: ["a", "b"],
            features: [],
            packages: []
        ).serialize()

        XCTAssertEqual(["a", "b"], sdkInfo["integrations"] as? [String])
    }

    func testSerializationValidFeatures() {
        let sdkInfo = SentrySdkInfo(
            name: "",
            version: "",
            integrations: [],
            features: ["c", "d"],
            packages: []
        ).serialize()

        XCTAssertEqual(["c", "d"], sdkInfo["features"] as? [String])
    }

    func testSPM_packageInfo() throws {
        SentrySdkInfo.setPackageManager(0)
        let actual = SentrySdkInfo.fromGlobals()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "spm:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testCarthage_packageInfo() throws {
        SentrySdkInfo.setPackageManager(2)
        let actual = SentrySdkInfo.fromGlobals()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "carthage:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testcocoapods_packageInfo() throws {
        SentrySdkInfo.setPackageManager(1)
        let actual = SentrySdkInfo.fromGlobals()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "cocoapods:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testNoPackageNames () {
        let actual = SentrySdkInfo(
            name: sdkName,
            version: "",
            integrations: [],
            features: [],
            packages: []
        )
        XCTAssertNil(Dynamic(actual).getPackageName(3).asString)
    }
    
    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a", "b"],
            features: ["c", "d"],
            packages: [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ]
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["a", "b"],
            "features": ["c", "d"],
            "packages": [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfo_RemovesDuplicates() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["b"],
            features: ["c"],
            packages: [
                ["name": "a", "version": "1"]
            ]
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["b", "b"],
            "features": ["c", "c"],
            "packages": [
                ["name": "a", "version": "1"],
                ["name": "a", "version": "1"]
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfo_IgnoresOrder() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a", "b"],
            features: ["c", "d"],
            packages: [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ]
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["b", "a"],
            "features": ["d", "c"],
            "packages": [
                ["name": "b", "version": "2"],
                ["name": "a", "version": "1"]
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_AllNil() {
        let dict = [
            "name": nil,
            "version": nil,
            "integrations": nil,
            "features": nil,
            "packages": nil
        ] as [String: Any?]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict as [AnyHashable: Any]))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = [
            "name": 0,
            "version": 0,
            "integrations": 0,
            "features": 0,
            "packages": 0
        ]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_WrongTypesInArrays() {
        let version = "10.3.1"
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a"],
            features: ["b"],
            packages: [
                ["name": "a", "version": "1"]
            ]
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": [0, [], "a", [:]],
            "features": [0, [], "b", [:]],
            "packages": [
                0,
                [],
                "b",
                [:],
                ["name": "a", "version": "1", "invalid": -1]
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfoIsString() {
        let dict = ["sdk": ""]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }

    func testglobal() throws {
        SentrySDK.start(options: Options())
        let actual = SentrySdkInfo.global()
        XCTAssertEqual(actual.name, SentryMeta.sdkName)
        XCTAssertEqual(actual.version, SentryMeta.versionString)
        XCTAssertTrue(actual.integrations.count > 0)
        XCTAssertTrue(actual.features.count > 0)
    }
    
    func testFromGlobalsWithExtraPackage() throws {
        let extraPackage = ["name": "test-package", "version": "1.0.0"]
        SentrySdkInfo.addPackageName(extraPackage["name"]!, version: extraPackage["version"]!)

        let actual = SentrySdkInfo.fromGlobals()
        XCTAssertEqual(actual.packages.count, 1)
        XCTAssertTrue(actual.packages.contains(extraPackage))
    }
    
    func testFromGlobalsWithExtraPackageAndPackageManager() throws {
        let extraPackage = ["name": "test-package", "version": "1.0.0"]
        SentrySdkInfo.addPackageName(extraPackage["name"]!, version: extraPackage["version"]!)
        SentrySdkInfo.setPackageManager(1)

        let actual = SentrySdkInfo.fromGlobals()
        XCTAssertEqual(actual.packages.count, 2)
        XCTAssertTrue(actual.packages.contains(extraPackage))
        XCTAssertTrue(actual.packages.contains(["name": "cocoapods:getsentry/\(SentryMeta.sdkName)", "version": SentryMeta.versionString]))
    }

    private func assertEmptySdkInfo(actual: SentrySdkInfo) {
        XCTAssertEqual(SentrySdkInfo(
            name: "",
            version: "",
            integrations: [],
            features: [],
            packages: []
        ), actual)
    }
}
